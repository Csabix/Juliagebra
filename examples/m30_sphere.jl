using Juliagebra

Juliagebra.Window() do 
    c1 = Point(3.0,0.0,0.0)
    p1 = Point(2.25,0.0,0.0)
    sphr1 = Sphere(c1,p1)

    c2 = Point(0.0,0.0,1.5)
    sphr2 = Sphere(c2,p1,color=(0.6,0.1,0.2,1.0))

    c3 = Point(0.0,0.0,0.0)
    g1 = ValueHolder(Float64,[Slider(0.0,0.93,5.0)]) do s1
        return Float64(s1)
    end
    sphr3 = Sphere(c3,g1; transparent=true)

    a = Point(-2.0, 1.0,-0.5)
    b = Point(-2.0,-1.0, 0.5)
    c = Point(-4.0,-1.0,-0.5)
    d = Point(-4.0, 1.0, 0.5)

    sphr4 = Sphere(a,b,c,d; color=(0.56,0.66,0.0), transparent=true)
end

