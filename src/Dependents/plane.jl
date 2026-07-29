
# ? ---------------------------------
# ! Plane
# ? ---------------------------------

const _INFINITE_PLANE_DISTANCE = 100

_get_dependent_plane(dep::DependentDNA) = dep
_get_dependent_plane(dep) = SourceValueHolder(Vec3D(dep))

function Plane(p0,p1,p2,color_style::Union{Nothing,String}=nothing;
    distance=_INFINITE_PLANE_DISTANCE,color="g")

    deps = DependentDNA[
        _get_dependent_plane(p0),
        _get_dependent_plane(p1),
        _get_dependent_plane(p2),
    ]

    n = ceil(Int16, log10(distance))

    ParametricSurface(range(-n,n,2*n+1),range(-n,n,2*n+1),deps,color_style;color=color,isInfinite=true) do u,v,p0,p1,p2
        dir1 = normalize(p1 - p0)
        dir2 = normalize(p2 - p0)
        normal = cross(dir1, dir2)
        perp = normalize(cross(dir1, normal))
        u = sign(u) * 10^abs(u)
        v = sign(v) * 10^abs(v)
        return p0 + (dir1 * v + perp * u)
    end

    return ValueHolder(PPlane,deps) do p0,p1,p2
        return PPlane(p0, normalize(cross(p1 - p0, p2 - p0)))
    end
end

# ? ---------------------------------
# ! Plane to PPlane intersection
# ? ---------------------------------

struct PPlaneOfPlane <: PrimitivesOf{PPlane}
    plane::PPlane
end
PrimitivesOf(self::PPlane) = PPlaneOfPlane(self)

Base.length(self::PPlaneOfPlane) = 1
Base.iterate(self::PPlaneOfPlane, index::Integer = 1) = index == 1 ? (self.plane, (index + 1)) : nothing

export Plane
