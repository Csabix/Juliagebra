using Juliagebra
using JuliaGLM

App()

function Triangle(a,b,c)
    return ParametricSurface(3,3,0.0,1.0,0.0,1.0,[a,b,c]) do u,v,a,b,c
        
        if (u>=0.5 && v>=0.5)
            u = 0.5
            v = 0.5
        end

        return (1-u-v) .* a .+ u .* b .+ v .* c
    end
end

#Sphere(2.5,0.0,0.0,0.0)

width = 10
height = 10

points = Dict()

for u in 1:10
    for v in 1:10
        uf = Float64(u-1) / Float64(width-1)
        vf = Float64(v-1) / Float64(height-1)

        uf = uf * (pi - 0.0) + 0.0
        vf = vf * (2*pi - 0.0) + 0.0

        #points[u,v] = Point(SpherePoint(uf,vf,2.5,0.0,0.0,0.0)...)
    end
end

for u in 1:9
    for v in 1:9
        #Triangle(points[u,v],points[u+1,v],points[u+1,v+1])
    end
end

for u in 2:10
    for v in 2:10
        #Triangle(points[u,v],points[u-1,v],points[u-1,v-1])
    end
end

radius = SourceValueHolder(2.5)
center = Point(0.0,0.0,0.0)
sphere = Sphere(center,radius)

sphereTriangles = GenericValueHolder(Vector,[sphere]) do sphere
    triangles = []
    ite = PTrianglesOfSphere(sphere)
    len = length(ite)

    for i in 1:len
        push!(triangles,ite[UInt(i)])
    end

    return triangles
end

const SPHERE_HIDDEN_DETAIL = 15
const SPHERE_TRIANGLE_COUNT = (SPHERE_HIDDEN_DETAIL-1)*(SPHERE_HIDDEN_DETAIL-1) + (SPHERE_HIDDEN_DETAIL-1)*(SPHERE_HIDDEN_DETAIL-1)
const SPHERE_HITBOX_LOAD = false

for i in 1:SPHERE_TRIANGLE_COUNT
    if (!SPHERE_HITBOX_LOAD)
        break
    end

    p0 = Point([sphereTriangles]) do sphereTriangles
        return sphereTriangles[i].v0   
    end
    p1 = Point([sphereTriangles]) do sphereTriangles
        return sphereTriangles[i].v1   
    end
    p2 = Point([sphereTriangles]) do sphereTriangles
        return sphereTriangles[i].v2   
    end

    Segment(p0,p1)
    Segment(p1,p2)
    Segment(p2,p0)

    Triangle(p0,p1,p2)
end

curveTMax = (2*pi)*5
curveRadius = 2.2
curvePoint = Point(-curveTMax-3.5,0,0)

curve = ParametricCurve(range(0,curveTMax,55),[curvePoint],color=(0.3,0.8,0.3)) do t,curvePoint
    z = cos(t) * curveRadius
    y = sin(t) * curveRadius
    x = t
    
    return curvePoint .+ (x,y,z)
end
sphere2CurveIntersection = Intersection(sphere,curve)

surface = ParametricSurface(50,50,-10.0,10.0,-10.0,10.0) do u,v
    x = u
    y = v
    z = (u^2 + v^2) * -0.05

    return (x,y,z)
end
sphere2SurfaceIntersection = Intersection(sphere,surface; maxIntersectionNum = 392)

for i in 1:100 
    Point([sphere2CurveIntersection]) do sphere2CurveIntersection
        return sphere2CurveIntersection[i]
    end
end

for i in 1:392
    ParametricCurve(range(0, 1, length = 2), [sphere2SurfaceIntersection]; width=3.0) do t, sphere2SurfaceIntersection
        s::PSegment = sphere2SurfaceIntersection[i]
        return s.p0 .* t .+ (1.0 - t) .* s.p1
    end
end

play!()