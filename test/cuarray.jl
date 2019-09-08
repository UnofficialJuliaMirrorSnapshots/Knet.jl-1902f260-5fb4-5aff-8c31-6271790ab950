include("header.jl")

if gpu() >= 0; @testset "cuarray" begin
    for nd in (1,2,3)
        sz = ntuple(i->8, nd)
        a0,b0 = rand(sz...),rand(sz...)
        a1,b1 = ka(a0),ka(b0)
        a2,b2 = Param(a0),Param(b0)
        a3,b3 = Param(a1),Param(b1)
        idx = ntuple(i->2:4, nd)
        @test getindex(a0,idx...) == getindex(a1,idx...)
        @test @gcheck getindex(a2,idx...)
        @test @gcheck getindex(a3,idx...)
        if nd == 1
            @test permutedims(a0) == permutedims(a1)
            @test @gcheck permutedims(a2)
            @test @gcheck permutedims(a3)
        elseif nd == 2
            @test permutedims(a0) == permutedims(a1)
            @test permutedims(a0,(2,1)) == permutedims(a1,(2,1))
            @test permutedims(a0,(1,2)) == permutedims(a1,(1,2))
            @test @gcheck permutedims(a2)
            @test @gcheck permutedims(a2,(2,1))
            @test @gcheck permutedims(a2,(1,2))
            @test @gcheck permutedims(a3)
            @test @gcheck permutedims(a3,(2,1))
            @test @gcheck permutedims(a3,(1,2))
        else
            @test permutedims(a0,(1,3,2)) == permutedims(a1,(1,3,2))
            @test @gcheck permutedims(a2,(1,3,2))
            @test @gcheck permutedims(a3,(1,3,2))
        end
        @test hcat(a0,b0) == hcat(a1,b1)
        @test vcat(a0,b0) == vcat(a1,b1)
        @test @gcheck hcat(a2,b2)
        @test @gcheck vcat(a2,b2)
        @test @gcheck hcat(a3,b3)
        @test @gcheck vcat(a3,b3)
        for i in 1:nd
            @test cat(a0,b0,dims=i) == cat(a1,b1,dims=i)
            @test @gcheck cat(a2,b2,dims=i)
            @test @gcheck cat(a3,b3,dims=i)
        end
        @test setindex!(a0,b0[idx...],idx...) == setindex!(a1,b1[idx...],idx...)
    end
end; end
    
