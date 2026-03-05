# To try this example you need DelaunayTriangulation package
using Juliagebra
using JuliaGLM
using DelaunayTriangulation # <-- third party dependency, slow start because of this

vec3 = Vec3D

App()

initial_positions = [vec3(col[1],col[2],0.5-sqrt((0.5-col[1])^2 + (0.5-col[2])^2)) for col = eachcol(rand(2, 20))]
movable_point_cloud = PointCloud(initial_positions)

triangulation = TriangleCluster(Mesh([],nothing),[movable_point_cloud]) do coords
    points = [getfield(p, f) for f in (:x, :y), p in coords]
    tri = triangulate(points)
    real_triangles = (t for t in each_triangle(tri) if all(v > 0 for v in t))
    return Mesh([coords[index] for index in Iterators.flatten(real_triangles)],nothing)
end

play!()