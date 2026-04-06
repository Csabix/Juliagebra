using Juliagebra

const MIN_POS = -10.0
const MAX_POS = 10.0
const MIN_RAD = 0.5
const MAX_RAD = 1.5

rand_coord() = rand() * (MAX_POS - MIN_POS) + MIN_POS
rand_rgb() = (rand(), rand(), rand())

for i in 1:50
    x = rand_coord()
    y = rand_coord()
    z = rand_coord()
    center = Point(x, y, z)
    radius = rand() * (MAX_RAD - MIN_RAD) + MIN_RAD
    p1 = Point(x + radius, y, z)
    Sphere(center, p1; color=(rand_rgb()...,1.0))
end

for i in 1:60
    x = rand_coord()
    y = rand_coord()
    z = rand_coord()
    center = Point(x, y, z)
    radius = rand() * (MAX_RAD - MIN_RAD) + MIN_RAD
    p1 = Point(x + radius, y, z)
    Sphere(center, p1; color=(rand_rgb()...,0.5))
end

Juliagebra.Wait()