
# ? ---------------------------------
# ! Plane
# ? ---------------------------------

const _INFINITE_PLANE_DISTANCE = 100

_get_dependent_plane(dep::DependentDNA) = dep
_get_dependent_plane(dep) = SourceValueHolder(Vec3D(dep))

function Plane(first,second,third,distance=_INFINITE_PLANE_DISTANCE,color_style::Union{Nothing,String}=nothing;
    color="g")

    deps = DependentDNA[
        _get_dependent_plane(first),
        _get_dependent_plane(second),
        _get_dependent_plane(third),
    ]

    n = ceil(Int16, log10(distance))

    ParametricSurface(range(-n,n,2*n+1),range(-n,n,2*n+1),deps;color=color) do u,v,a,b,c
        dir1 = normalize(b - a)
        dir2 = normalize(c - a)
        normal = cross(dir1, dir2)
        perp = normalize(cross(dir1, normal))
        u = sign(u) * 10^abs(u)
        v = sign(v) * 10^abs(v)
        return a + (dir1 * v + perp * u)
    end

    return ValueHolder(PPlane,deps) do a,b,c
        return PPlane(a, normalize(cross(b - a, c - a)))
    end
end

# ? ---------------------------------
# ! Plane to PPlane intersection
# ? ---------------------------------

struct PPlaneOfPlane <: PrimitivesOf{PSegment} # TODO: change to PPlane
    plane::PPlane
end
PrimitivesOf(self::PPlane) = return PPlaneOfPlane(self)

Base.length(self::PPlaneOfPlane) = 1

function Base.getindex(self::PPlaneOfPlane, index::Integer)::Union{Nothing, PPlane}
    println("index: ", index)
    if (index == 1)
        println(self.plane)
        return self.plane
    else
        return nothing
    end
end

function Base.iterate(self::PPlaneOfPlane, index::Integer = 1)
    println("iterate: ", index)
    if (index == 1)
        return (self[index], (index + 1))
    else
        return nothing
    end
end







export Plane
