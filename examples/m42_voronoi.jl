using Juliagebra
using JuliaGLM
using DelaunayTriangulation # <-- third party dependency, slow start because of this

vec3 = Vec3D

App()

initial_positions = [vec3(col[1],col[2],0.1) for col = eachcol(rand(2, 20))]
movable_point_cloud = PointCloud(initial_positions)

voro_points = PointCloud([movable_point_cloud]) do coords
    points = [getfield(p, f) for f in (:x, :y), p in coords]
    tri1 = triangulate(points)
    vorn2 = voronoi(tri1)
    return [(x,y,0.1) for (x,y) = vorn2.polygon_points]
end

play!()