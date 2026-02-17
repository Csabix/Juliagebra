
# ? ---------------------------------
# ! Triangle
# ? ---------------------------------

function _triangleSurfaceFunc(u,v,a,b,c)
    if (u>=0.5 && v>=0.5)
        u = 0.5
        v = 0.5
    end

    return (1-u-v) .* a .+ u .* b .+ v .* c
end

function Triangle(a::PointPlan,b::PointPlan,c::PointPlan,;transparent=false,color=(0.5,0.6,0.2))
    return ParametricSurface(3,3,0.0,1.0,0.0,1.0,[a,b,c]; transparent=transparent,color=color) do u,v,a,b,c
        return _triangleSurfaceFunc(u,v,a,b,c)
    end
end

function Triangle(a::PointPlan,b::PointPlan,c;transparent=false,color=(0.5,0.6,0.2))
    cc = Vec3D(c)
    return ParametricSurface(3,3,0.0,1.0,0.0,1.0,[a,b]; transparent=transparent,color=color) do u,v,a,b
        return _triangleSurfaceFunc(u,v,a,b,cc)
    end
end

function Triangle(a::PointPlan,b,c::PointPlan;transparent=false,color=(0.5,0.6,0.2))
    bb = Vec3D(b)
    return ParametricSurface(3,3,0.0,1.0,0.0,1.0,[a,c]; transparent=transparent,color=color) do u,v,a,c
        return _triangleSurfaceFunc(u,v,a,bb,c)
    end
end

function Triangle(a,b::PointPlan,c::PointPlan;transparent=false,color=(0.5,0.6,0.2))
    aa = Vec3D(a)
    return ParametricSurface(3,3,0.0,1.0,0.0,1.0,[c,b]; transparent=transparent,color=color) do u,v,c,b
        return _triangleSurfaceFunc(u,v,aa,b,c)
    end
end

function Triangle(a::PointPlan,b,c;transparent=false,color=(0.5,0.6,0.2))
    bb = Vec3D(b)
    cc = Vec3D(c)
    return ParametricSurface(3,3,0.0,1.0,0.0,1.0,[a]; transparent=transparent,color=color) do u,v,a
        return _triangleSurfaceFunc(u,v,a,bb,cc)
    end
end

function Triangle(a,b::PointPlan,c;transparent=false,color=(0.5,0.6,0.2))
    aa = Vec3D(a)
    cc = Vec3D(c)
    return ParametricSurface(3,3,0.0,1.0,0.0,1.0,[b]; transparent=transparent,color=color) do u,v,b
        return _triangleSurfaceFunc(u,v,aa,b,cc)
    end
end

function Triangle(a,b,c::PointPlan;transparent=false,color=(0.5,0.6,0.2))
    aa = Vec3D(a)
    bb = Vec3D(b)
    return ParametricSurface(3,3,0.0,1.0,0.0,1.0,[c]; transparent=transparent,color=color) do u,v,c
        return _triangleSurfaceFunc(u,v,aa,bb,c)
    end
end

function Triangle(a,b,c;transparent=false,color=(0.5,0.6,0.2))
    aa = Vec3D(a)
    bb = Vec3D(b)
    cc = Vec3D(c)
    return ParametricSurface(3,3,0.0,1.0,0.0,1.0; transparent=transparent,color=color) do u,v
        return _triangleSurfaceFunc(u,v,aa,bb,cc)
    end
end

export Triangle