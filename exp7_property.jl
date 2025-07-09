
mutable struct Alma
    a::Int
end

function Base.getindex(self::Alma,idx::Val{:A})
    return self.a
end

abstract type A end

function Base.getindex(self::Alma,idx::Type{A})
    return self.a
end

function A()

end

aa = Alma(5)
A()
println("$(aa[Val(:A)])")
println("$(aa[A])")

