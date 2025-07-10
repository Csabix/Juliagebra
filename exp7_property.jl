
mutable struct Alma
    a::Int
end

function Base.getindex(self::Alma,idx::Val{:A})
    return self.a
end

struct Aa end

const A = Aa()

function Base.getindex(self::Alma,idx::Aa)
    return self.a
end

function A()

end

aa = Alma(5)
A()
println("$(aa[Val(:A)])")
println("$(aa[A])")


@enum Coord X Y Z

function Base.getindex(self::Alma, field::Val{X})
    return self.a
end

println("$(aa[Val(X)])")
