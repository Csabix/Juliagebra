using Juliagebra

App()

s1 = Slider()

s2 = Slider(-10,10)

s3x = Slider(-5,15)
s3y = Slider(-5,15)
s3z = Slider(-5,15)

p1 = Point([s3x,s3y,s3z]) do s3x,s3y,s3z
    return (s3x,s3y,s3z)
end

s4 = Slider(-25,25,[p1]) do p1
    return ((p1.x+p1.y+p1.z)/3.0)
end

s5 = Slider(-10,8.9,10)

play!()