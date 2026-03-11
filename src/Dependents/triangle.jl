
# ? ---------------------------------
# ! Triangle
# ? ---------------------------------

function _triangleSurfaceFunc(u,v,a,b,c)
    if (u>=0.5 && v>=0.5)
        u = 0.5
        v = 0.5
    end

    return Vec3D((1-u-v) .* a .+ u .* b .+ v .* c)
end

function Triangle(a::PointDependent,b::PointDependent,c::PointDependent,;transparent=false,color=(0.5,0.6,0.2))
    return ParametricSurface(range(0,1,3), range(0,1,3), [a,b,c]; transparent=transparent,color=color) do u,v,a,b,c
        return _triangleSurfaceFunc(u,v,a,b,c)
    end
end

function Triangle(a::PointDependent,b::PointDependent,c;transparent=false,color=(0.5,0.6,0.2))
    cc = Vec3D(c)
    return ParametricSurface(range(0,1,3),range(0,1,3),[a,b]; transparent=transparent,color=color) do u,v,a,b
        return _triangleSurfaceFunc(u,v,a,b,cc)
    end
end

function Triangle(a::PointDependent,b,c::PointDependent;transparent=false,color=(0.5,0.6,0.2))
    bb = Vec3D(b)
    return ParametricSurface(range(0,1,3),range(0,1,3),[a,c]; transparent=transparent,color=color) do u,v,a,c
        return _triangleSurfaceFunc(u,v,a,bb,c)
    end
end

function Triangle(a,b::PointDependent,c::PointDependent;transparent=false,color=(0.5,0.6,0.2))
    aa = Vec3D(a)
    return ParametricSurface(range(0,1,3),range(0,1,3),[c,b]; transparent=transparent,color=color) do u,v,c,b
        return _triangleSurfaceFunc(u,v,aa,b,c)
    end
end

function Triangle(a::PointDependent,b,c;transparent=false,color=(0.5,0.6,0.2))
    bb = Vec3D(b)
    cc = Vec3D(c)
    return ParametricSurface(range(0,1,3),range(0,1,3),[a]; transparent=transparent,color=color) do u,v,a
        return _triangleSurfaceFunc(u,v,a,bb,cc)
    end
end

function Triangle(a,b::PointDependent,c;transparent=false,color=(0.5,0.6,0.2))
    aa = Vec3D(a)
    cc = Vec3D(c)
    return ParametricSurface(range(0,1,3),range(0,1,3),[b]; transparent=transparent,color=color) do u,v,b
        return _triangleSurfaceFunc(u,v,aa,b,cc)
    end
end

function Triangle(a,b,c::PointDependent;transparent=false,color=(0.5,0.6,0.2))
    aa = Vec3D(a)
    bb = Vec3D(b)
    return ParametricSurface(range(0,1,3),range(0,1,3),[c]; transparent=transparent,color=color) do u,v,c
        return _triangleSurfaceFunc(u,v,aa,bb,c)
    end
end

function Triangle(a,b,c;transparent=false,color=(0.5,0.6,0.2))
    aa = Vec3D(a)
    bb = Vec3D(b)
    cc = Vec3D(c)
    return ParametricSurface(range(0,1,3),range(0,1,3); transparent=transparent,color=color) do u,v
        return _triangleSurfaceFunc(u,v,aa,bb,cc)
    end
end

export Triangle