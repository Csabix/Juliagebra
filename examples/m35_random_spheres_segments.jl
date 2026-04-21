using Juliagebra

App()

const MIN_POS = -10.0
const MAX_POS = 10.0
const MIN_RAD = 0.5
const MAX_RAD = 2.5

rand_coord() = rand() * (MAX_POS - MIN_POS) + MIN_POS

for i in 1:10
    x = rand_coord()
    y = rand_coord()
    z = rand_coord()
    center = Point(x, y, z)
    radius = rand() * (MAX_RAD - MIN_RAD) + MIN_RAD
    p1 = Point(x + radius, y, z)
    Sphere(center, p1)
end

segment_types = [
    SOLID, 
    DASHED, 
    DOTTED, 
    WAVE, 
    DASH_DOT, 
    ARROW
]

for stype in segment_types
    for i in 1:2
        pt_a = Point(rand_coord(), rand_coord(), rand_coord())
        pt_b = Point(rand_coord(), rand_coord(), rand_coord())
        Segment(pt_a, pt_b, type=stype,width=14.0f0)
    end
end

Juliagebra.Wait()