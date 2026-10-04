function get_triangulated(values::Matrix{T}) where T
    h, w = Base.size(values)
    return Base.Iterators.flatten((
        (
            values[v + 1, u],
            values[v,     u],
            values[v,     u + 1],
            values[v + 1, u + 1],
            values[v + 1, u],
            values[v,     u + 1]
        )
        for v in 1:(h - 1) for u in 1:(w - 1)
    ))
end

struct PTrianglesOfSurface <: PrimitivesOf{PTriangle}
    values::Matrix{Vec3D}
end

Base.length(self::PTrianglesOfSurface) = (Base.size(self.values, 1) - 1) * (Base.size(self.values, 2) - 1) * 2

function Base.getindex(triangles::PTrianglesOfSurface, index::Integer)::PTriangle
    values = triangles.values
    num_cols = size(values)[2] - 1

    cell_idx = div(index - 1, 2)
    
    v = div(cell_idx, num_cols) + 1
    u = rem(cell_idx, num_cols) + 1

    return rem(index - 1, 2) == 0 ?
            PTriangle(values[v,u], values[v+1,u], values[v,u+1]) :
            PTriangle(values[v+1,u], values[v+1,u+1], values[v,u+1])
end

function Base.iterate(triangles::PTrianglesOfSurface, n::Int = 1)
    h, w = size(triangles.values)
    total_triangles = 2 * (h - 1) * (w - 1)
    if n > total_triangles || h < 2 || w < 2
        return nothing
    end
    return triangles[n]
end