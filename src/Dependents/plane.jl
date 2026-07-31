
# ? ---------------------------------
# ! Plane
# ? ---------------------------------

const PLANE_N_LENGTH = ceil(Int16, log10(1000))

_get_dependent_plane(dep::DependentDNA) = dep
_get_dependent_plane(dep) = SourceValueHolder(Vec3D(dep))

function Plane(p0,p1,p2,color_style::Union{Nothing,String}=nothing;
    color="g")

    deps = DependentDNA[
        _get_dependent_plane(p0),
        _get_dependent_plane(p1),
        _get_dependent_plane(p2),
    ]

    ParametricSurface(
        range(-PLANE_N_LENGTH,PLANE_N_LENGTH,2*PLANE_N_LENGTH+1),
        range(-PLANE_N_LENGTH,PLANE_N_LENGTH,2*PLANE_N_LENGTH+1),
        deps,color_style;color=color,isInfinite=true) do u,v,p0,p1,p2

        dir1 = normalize(p1 - p0)
        dir2 = normalize(p2 - p0)
        normal = cross(dir1, dir2)
        perp = normalize(cross(dir1, normal))
        u = sign(u) * 10^abs(u)
        v = sign(v) * 10^abs(v)
        return p0 + (dir1 * v + perp * u)
    end

    pplane = ValueHolder(PPlane,deps) do p0,p1,p2
        return PPlane(p0, normalize(cross(p1 - p0, p2 - p0)))
    end

    Segment(p0,p1,color_style;color=color,style="--")
    Segment(p0,p2,color_style;color=color,style="--")
    Segment([pplane],color_style;color=color,style="->",size=9.0) do plane
        return PSegment(plane.p, plane.p + plane.n)
    end

    return pplane
end

function Plane(callback::Function,dependents::Vector{<:DependentDNA}=DependentDNA[],color_style::Union{Nothing,String}=nothing;
    color="g")

    ParametricSurface(
        range(-PLANE_N_LENGTH,PLANE_N_LENGTH,2*PLANE_N_LENGTH+1),
        range(-PLANE_N_LENGTH,PLANE_N_LENGTH,2*PLANE_N_LENGTH+1),
        dependents,color_style;color=color,isInfinite=true) do u,v,param1,param2
            
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

    return ValueHolder(PPlane, dependents) do param1,param2
        pplane = callback(param1,param2)
        if (pplane === nothing) return PPlane(Vec3DNan,Vec3DNan) end
        return pplane
    end
end

function Plane(point,line,color_style::Union{Nothing,String}=nothing;
    color="g")

    return Plane([point,line],color_style;color=color) do p0,l
        normal = cross(p0 - p(l), v(l))
        return PPlane(p0,normal)
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
