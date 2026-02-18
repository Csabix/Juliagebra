# To try this example you need DelaunayTriangulation package
using Juliagebra
using JuliaGLM
using DelaunayTriangulation # <-- third party dependency, slow start because of this

vec3 = Vec3D

App()

initial_positions = [vec3(col[1],col[2],0.1) for col = eachcol(rand(2, 20))]
movable_point_cloud = PointCloud(initial_positions)

triangulation = GenericValueHolder(Any,[movable_point_cloud]) do coords
    points = [getfield(p, f) for f in (:x, :y), p in coords]
    return triangulate(points)
end
voro = GenericValueHolder(voronoi,Any,[triangulation])

SegmentSequence([movable_point_cloud,triangulation];color=(0,0,1),width=3.0) do coords, tri
    real_edges = (e for e in each_edge(tri) if all(v > 0 for v in e))
    return [coords[index] for index in Iterators.flatten(real_edges)]
end

voro_points = PointCloud([voro];width=10.0,color=(1,1,0)) do voro
    return [(x,y,0.1) for (x,y) = voro.polygon_points]
end

SegmentSequence([voro_points,voro];color=(0,0,0)) do coords, voro
    edges = reduce(vcat, [
        [x, y] for vec in values(voro.polygons) 
        for (x, y) in zip(vec, @view vec[2:end]) 
        if x > 0 && y > 0
    ], init=Int[])

    real_edges = (e for e in edges if all(v > 0 for v in e))
    return [coords[index] for index in Iterators.flatten(real_edges)]
end

play!()