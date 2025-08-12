abstract type aChain end
abstract type bChain <: aChain end
abstract type cChain <: aChain end
abstract type dChain <: bChain end
abstract type eChain <: dChain end

setName(self::Any) = error("No setname 4 any!")

mutable struct A <: aChain
    name::String
end

mutable struct B <: bChain
    name::String
end

mutable struct C <: cChain
    name::String
end

mutable struct D <: dChain
    name::String
end

mutable struct E <: eChain
    name::String
end

mutable struct F <: dChain
    name::String
end



setName(self::A,s::String) = (self.name = s * "A")
setName(self::B,s::String) = (self.name = s * "B")
setName(self::C,s::String) = (self.name = s * "C")
setName(self::D,s::String) = (self.name = s * "D")
setName(self::E,s::String) = (self.name = s * "E")
setName(self::F,s::String) = (self.name = s * "F")

mutable struct AU
    name::String
end

mutable struct BU
    name::String
end

mutable struct CU
    name::String
end

mutable struct DU
    name::String
end

mutable struct EU
    name::String
end

mutable struct FU
    name::String
end

setName(self::AU,s::String) = (self.name = s * "A")
setName(self::BU,s::String) = (self.name = s * "B")
setName(self::CU,s::String) = (self.name = s * "C")
setName(self::DU,s::String) = (self.name = s * "D")
setName(self::EU,s::String) = (self.name = s * "E")
setName(self::FU,s::String) = (self.name = s * "F")

setName(self::Any,s::String) = error("No setname 44 any!")


const aChainTs = [A,B,C,D,E,F]
function test_abstract_vector(n)
    v = Vector{aChain}()
    for i in 1:n
        j = rand([1,2,3,4,5,6])
        push!(v, aChainTs[j]("$(j)"))
    end

    for i in 1:n
        item = rand(v)
        setName(item,"$i")
    end

    return v
end

const aUnion = Union{AU, BU,CU,DU,EU,FU}
const aUnionTs = [AU, BU,CU,DU,EU,FU]
function test_union_vector(n)
    v = Vector{aUnion}()
    for i in 1:n
        j = rand([1,2,3,4,5,6])
        push!(v, aUnionTs[j]("$(j)"))
    end
   
    for i in 1:n
        item = rand(v)
        setName(item,"$i")
    end
   
    return v
end

using BenchmarkTools

println("Abstract vector:")

@btime test_abstract_vector(10_000)

println("Union vector:")

@btime test_union_vector(10_000)