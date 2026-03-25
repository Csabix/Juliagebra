# To try this example you need DelaunayTriangulation package
using Juliagebra
using JuliaGLM
using DelaunayTriangulation # <-- third party dependency, slow start because of this

vec3 = Vec3D

Juliagebra.Window() do 
    initial_positions = [vec3(col[1],col[2],0.1) for col = eachcol(rand(2, 20))]
    movable_point_cloud = PointSet(initial_positions)

    triangulation = GenericValueHolder(Any,[movable_point_cloud]) do coords
        points = [getfield(p, f) for f in (:x, :y), p in coords]
        return triangulate(points)
    end
    voro = GenericValueHolder(voronoi,Any,[triangulation])

    s1 = SegmentSequence([movable_point_cloud,triangulation];color=(0,0,1),width=3.0) do coords, tri
        real_edges = (e for e in each_edge(tri) if all(v > 0 for v in e))
        
        aa = [coords[index] for index in Iterators.flatten(real_edges)]
        return aa
    end

    # TODO: Fix GL_INVALID_VALUE!
    s2 = SegmentSequence([voro];color=(0,0,0)) do voro
        coords = [vec3(x,y,0.1) for (x,y) = voro.polygon_points]
        edges = reduce(vcat, [
            [x, y] for vec in values(voro.polygons) 
            for (x, y) in zip(vec, @view vec[2:end]) 
            if x > 0 && y > 0
        ], init=Int[])
                
        real_edges = (e for e in edges if all(v > 0 for v in e))
        
        aa = [coords[index] for index in Iterators.flatten(real_edges)]
        return aa
    end

    PointSequence([Intersection(s1,s2;maxIntersectionNum=300)])
end
