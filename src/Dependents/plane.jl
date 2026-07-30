
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

function Plane(callback::Function,dependents::Vector{<:DependentDNA}=DependentDNA[],color_style::Union{Nothing,String}=nothing;
    distance=_INFINITE_PLANE_DISTANCE,color="g")

    n = ceil(Int16, log10(distance))

    ParametricSurface(range(-n,n,2*n+1),range(-n,n,2*n+1),dependents,color_style;color=color,isInfinite=true) do u,v,param1,param2
        pplane = callback(param1,param2)
        if (pplane === nothing) return nothing end

        vector = Vec3D(1,0,0)
        # ? picking a vector that is non collinear with the plane normal
        if (pplane.n.y == 0.0 && pplane.n.z == 0)
            vector = Vec3D(0,1,0)
        end

        dir1 = normalize(cross(vector, pplane.n))
        perp = normalize(cross(dir1, pplane.n))
        u = sign(u) * 10^abs(u)
        v = sign(v) * 10^abs(v)
        return pplane.p + (dir1 * v + perp * u)
    end
end

function Plane(point,line,color_style::Union{Nothing,String}=nothing;
    distance=_INFINITE_PLANE_DISTANCE,color="g")

    Plane([point,line],color_style;distance=distance,color=color) do p,l
        return PPlane(p,v(l))
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
