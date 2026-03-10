using Juliagebra
using JuliaGLM

Juliagebra.Window() do 
    s1 = Slider()
    s2 = Slider(10.0)
    s3 = Slider(-10,10)
    s4 = Slider(-10,6,10)

    s5x = Slider(-5,15; label="s5x")
    s5y = Slider(-5,15; label="s5y")
    s5z = Slider(-5,15; label="s5z")
    
    p1 = Point([s5x,s5y,s5z]) do s5x,s5y,s5z
       return (s5x,s5y,s5z)
    end

    s6 = Slider([p1]) do p1
        return Vec3F(-(abs(p1.x)+abs(p1.y)+abs(p1.z)),p1.x,abs(p1.x)+abs(p1.y)+abs(p1.z))
    end
end