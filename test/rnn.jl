include("header.jl")
using Knet: rnntest, rnnforw
macro gcheck1(ex); esc(:(@gcheck $ex (rtol=0.2, atol=0.05))); end

if gpu() >= 0; @testset "rnn" begin

    eq(a,b)=all(map((x,y)->(x==y==nothing || isapprox(x,y)),a,b))
    rxhc(r,x,h,c;o...)=(r.h=h;r.c=c;r(x;o...))
    D,X,H,B,T = Float64,32,32,16,8 # Keep X==H to test skipInput
    P = Param

    for M=(:relu,:tanh,:lstm,:gru), L=1:2, I=(:false,:true), BI=(:false,:true)
        # println((:rnninit,X,H,:dataType,D, :rnnType,M, :numLayers,L, :skipInput,I, :bidirectional,BI, :binit,xavier))
        # global rnew,r,w,x1,x2,x3,hx1,cx1,hx2,cx2,hx3,cx3
        # global rcpu,wcpu,x1cpu,x2cpu,x3cpu,hx1cpu,cx1cpu,hx2cpu,cx2cpu,hx3cpu,cx3cpu
        Knet.seed!(2)

        r = RNN(X, H; dataType=D, rnnType=M, numLayers=L, skipInput=I, bidirectional=BI, binit=xavier) # binit=zeros does not pass gchk
        w = r.w
        rcpu = RNN(X, H; dataType=D, rnnType=M, numLayers=L, skipInput=I, bidirectional=BI, binit=xavier, usegpu=false)
        wcpu = rcpu.w
        @test eltype(wcpu) == eltype(w)
        @test size(wcpu) == size(w)
        copyto!(value(wcpu), value(w))
        @test rcpu.w === wcpu
        @test wcpu == w
        HL = BI ? 2L : L
        BT = B*T

        # rnnforw(r...) calls the cudnn gpu implementation
        # rnntest(r...) calls the manual cpu/gpu implementation (does not support batchSizes)
        # rnnforw(rcpu...) calls rnntest for cpu inputs
        # (r::RNN)(x...) is the new interface

        ## Test 1-D x
        x1cpu = randn(D,X); x1 = ka(x1cpu)
        hx1cpu = randn(D,H,1,HL); hx1 = ka(hx1cpu)
        cx1cpu = randn(D,H,1,HL); cx1 = ka(cx1cpu)
        # x
        r.h = r.c = rcpu.h = rcpu.c = nothing
        @test eq(rnnforw(r,w,x1),rnntest(r,w,x1))
        @test eq(rnnforw(r,w,x1),rnnforw(rcpu,wcpu,x1cpu))
        @test @gcheck1 r(P(x1))
        @test @gcheck1 rcpu(P(x1cpu))
        # x,batchSizes
        @test eq(rnnforw(r,w,x1;batchSizes=[1]),rnntest(r,w,x1))
        #@test eq(rnnforw(r,w,x1;batchSizes=[1]),rnnforw(rcpu,wcpu,x1cpu;batchSizes=[1]))
        @test @gcheck1 r(P(x1),batchSizes=[1])
        #@test @gcheck1 rcpu(P(x1cpu),batchSizes=[1])
        # x,hidden
        @test eq(rnnforw(r,w,x1,hx1,cx1),rnntest(r,w,x1,hx1,cx1))
        @test eq(rnnforw(r,w,x1,hx1,cx1),rnnforw(rcpu,wcpu,x1cpu,hx1cpu,cx1cpu))
        @test @gcheck1 rxhc(r,P(x1),P(hx1),P(cx1))
        @test @gcheck1 rxhc(rcpu,P(x1cpu),P(hx1cpu),P(cx1cpu))
        # x,hidden,batchSizes
        @test eq(rnnforw(r,w,x1,hx1,cx1;batchSizes=[1]),rnntest(r,w,x1,hx1,cx1))
        #@test eq(rnnforw(r,w,x1,hx1,cx1;batchSizes=[1]),rnnforw(rcpu,wcpu,x1cpu,hx1cpu,cx1cpu;batchSizes=[1]))
        @test @gcheck1 rxhc(r,P(x1),P(hx1),P(cx1),batchSizes=[1])
        #@test @gcheck1 rxhc(rcpu,P(x1cpu),P(hx1cpu),P(cx1cpu),batchSizes=[1])

        ## Test 2-D x
        x2cpu =  randn(D,X,B); x2 = ka(x2cpu)
        hx2cpu = randn(D,H,B,HL); hx2 = ka(hx2cpu)
        cx2cpu = randn(D,H,B,HL); cx2 = ka(cx2cpu)
        # x
        r.h = r.c = rcpu.h = rcpu.c = nothing
        @test eq(rnnforw(r,w,x2),rnntest(r,w,x2))
        @test eq(rnnforw(r,w,x2),rnnforw(rcpu,wcpu,x2cpu))
        @test @gcheck1 r(P(x2)) 
        @test @gcheck1 rcpu(P(x2cpu)) 
        # x,hidden
        @test eq(rnnforw(r,w,x2,hx2,cx2),rnntest(r,w,x2,hx2,cx2))
        @test eq(rnnforw(r,w,x2,hx2,cx2),rnnforw(rcpu,wcpu,x2cpu,hx2cpu,cx2cpu))
        @test @gcheck1 rxhc(r,P(x2),P(hx2),P(cx2))
        @test @gcheck1 rxhc(rcpu,P(x2cpu),P(hx2cpu),P(cx2cpu))
        # x,hidden,batchSizes
        @test eq(rnnforw(r,w,x2,hx2,cx2;batchSizes=[B]),rnntest(r,w,x2,hx2,cx2))
        #@test eq(rnnforw(r,w,x2,hx2,cx2;batchSizes=[B]),rnnforw(rcpu,wcpu,x2cpu,hx2cpu,cx2cpu;batchSizes=[B]))
        for b in ([B],[B÷2,B÷2],[B÷2,B÷4,B÷4])
            hx2acpu = randn(D,H,b[1],HL); hx2a = ka(hx2acpu)
            cx2acpu = randn(D,H,b[1],HL); cx2a = ka(cx2acpu)
            @test @gcheck1 rxhc(r,P(x2),P(hx2a),P(cx2a),batchSizes=b) 
            #@test @gcheck1 rxhc(rcpu,P(x2cpu),P(hx2acpu),P(cx2acpu),batchSizes=b) # TODO
            r.h = r.c = rcpu.h = rcpu.c = nothing
            @test @gcheck1 r(P(x2),batchSizes=b) 
            #@test @gcheck1 rcpu(P(x2cpu),batchSizes=b) # TODO
        end

        ## Test 3-D x
        x3cpu = randn(D,X,B,T); x3 = ka(x3cpu)
        hx3cpu = randn(D,H,B,HL); hx3 = ka(hx3cpu)
        cx3cpu = randn(D,H,B,HL); cx3 = ka(cx3cpu)
        # x
        r.h = r.c = rcpu.h = rcpu.c = nothing
        @test eq(rnnforw(r,w,x3),rnntest(r,w,x3))
        @test eq(rnnforw(r,w,x3),rnnforw(rcpu,wcpu,x3cpu))
        @test @gcheck1 r(P(x3)) 
        @test @gcheck1 rcpu(P(x3cpu)) 
        # x,hidden
        @test eq(rnnforw(r,w,x3,hx3,cx3),rnntest(r,w,x3,hx3,cx3))
        @test eq(rnnforw(r,w,x3,hx3,cx3),rnnforw(rcpu,wcpu,x3cpu,hx3cpu,cx3cpu))
        @test @gcheck1 rxhc(r,P(x3),P(hx3),P(cx3))
        @test @gcheck1 rxhc(rcpu,P(x3cpu),P(hx3cpu),P(cx3cpu))
        # x,hidden,batchSizes
        @test eq(rnnforw(r,w,x3,hx3,cx3;batchSizes=[B for t=1:T]),rnntest(r,w,x3,hx3,cx3))
        #@test eq(rnnforw(r,w,x3,hx3,cx3;batchSizes=[B]),rnnforw(rcpu,wcpu,x3cpu,hx3cpu,cx3cpu;batchSizes=[B]))
        for b in ([BT],[BT÷2,BT÷2],[BT÷2,BT÷4,BT÷4])
            hx3acpu = randn(D,H,b[1],HL); hx3a = ka(hx3acpu)
            cx3acpu = randn(D,H,b[1],HL); cx3a = ka(cx3acpu)
            @test @gcheck1 rxhc(r,P(x3),P(hx3a),P(cx3a),batchSizes=b)
            #@test @gcheck1 rxhc(rcpu,P(x3cpu),P(hx3acpu),P(cx3acpu),batchSizes=b)
            r.h = r.c = rcpu.h = rcpu.c = nothing
            @test @gcheck1 r(P(x3),batchSizes=b) 
            #@test @gcheck1 rcpu(P(x3cpu),batchSizes=b) 
        end

        ## Test new interface in 3-D
        rnew = RNN(X, H; dataType=D, rnnType=M, numLayers=L, skipInput=I, bidirectional=BI, binit=xavier)
        copyto!(value(rnew.w), value(w))
        # x
        rnew.c = rnew.h = nothing
        yold1 = rnnforw(r,w,x3)
        ynew1 = rnew(x3)
        @test isapprox(yold1[1], ynew1)
        @test @gcheck1 rnew(P(x3)) 
        # x,hidden
        rnew.h = P(hx3); rnew.c = P(cx3)
        yold2 = rnnforw(r,w,x3,hx3,cx3)
        ynew2 = rnew(x3)
        @test isapprox(yold2[1], ynew2)
        @test isapprox(yold2[2], rnew.h)
        if M == :lstm; @test isapprox(yold2[3], rnew.c); end
        @test @gcheck1 rxhc(rnew,P(x3),P(hx3),P(cx3))
        # x,hidden,batchSizes
        rnew.h = P(hx3); rnew.c = P(cx3)
        bs = [B for t=1:T]
        yold3 = rnnforw(r,w,x3,hx3,cx3; batchSizes=bs)
        ynew3 = rnew(x3, batchSizes=bs)
        @test isapprox(yold3[1], ynew3)
        @test isapprox(yold3[2], rnew.h)
        if M == :lstm; @test isapprox(yold3[3], rnew.c); end
        @test @gcheck1 rxhc(rnew,P(x3),P(hx3),P(cx3),batchSizes=bs)

        function rmulti(r,xs,hx=nothing,cx=nothing)
            r.h,r.c = hx,cx
            y = Any[]
            for x in xs
                push!(y, r(x))
            end
            y = reshape(cat1d(y...), size(y[1],1), size(y[1],2), :)
            return y,r.h,r.c
        end

        # compare result and diff between multi-step and single-step
        if !BI
            T2 = T÷2
            x3a = x3[:,:,1:T2]
            x3b = x3[:,:,1+T2:end]
            y1,h1,c1 = rmulti(rnew, Any[x3], hx3, cx3)
            y2,h2,c2 = rmulti(rnew, Any[x3a,x3b], hx3, cx3)
            @test isapprox(y1,y2)
            @test isapprox(h1,h2)
            if M == :lstm; @test isapprox(c1,c2); end
            @test @gcheck1 rmulti(rnew, Any[x3], hx3, cx3)[1] 
            @test @gcheck1 rmulti(rnew, Any[x3a,x3b], hx3, cx3)[1] 
        end

        # rnnparam, rnnparams
        for m in (1,2)
            for l in 1:L
                for i in 1:(M==:lstm ? 8 : M==:gru ? 6 : 2)
                    #@show M,L,I,l,i,m
                    @test rnnparam(r,l,i,m) == rnnparam(rcpu,l,i,m)
                end
            end
        end
        @test all(map(==, rnnparams(r), rnnparams(rcpu)))
    end # for
end # @testset begin
end # if gpu() >= 0

nothing
