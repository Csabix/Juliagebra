using Juliagebra

App()

c1 = Point(0.0,0.0,0.0)
p1 = Point(0.75,0.0,0.75)
sphr1 = Sphere(c1,p1)

c2 = Point(0.0,0.0,1.5)
sphr2 = Sphere(c2,p1,color=(0.6,0.1,0.2))

c3 = Point(-5.0,0.0,5.0)
s1 = Slider(0.0,5.0)
g1 = GenericValueHolder(Float64,[s1]) do s1
    return Float64(s1)
end


sphr3 = Sphere(c3,g1)

a = Point( 1.0, 1.0,-6.0)
b = Point( 1.0,-1.0,-5.0)
c = Point(-1.0,-1.0,-6.0)
d = Point(-1.0, 1.0,-5.0)

sphr4 = Sphere(a,b,c,d)

play!()


