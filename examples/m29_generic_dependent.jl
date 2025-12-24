using Juliagebra
using JuliaGLM

App()

# ? Starting value decides the type
# ? so T will be the type of "96.0".
gd1 = GenericDependent(96.0)

txt1 = TextBox([gd1]) do gd1
    return  "gd1   T: $(gd1[:T])\n" *
            "gd1 val: $(gd1[:val])"
end

# ? {T} parametric input decides the type,
# ? So "96.0" gets converted to "Float32(96.0)"
gd2 = GenericDependent{Float32}(96.0)

txt2 = TextBox([gd2]) do gd2
    return  "gd2   T: $(gd2[:T])\n" *
            "gd2 val: $(gd2[:val])"
end

p1 = Point(0,0,0)

# ? {T} parametric input decides the type.
gd3 = GenericDependent{Vec3F}((0,0,0),[p1]) do p1
    return Vec3F(p1[:xyz])
end

txt3 = TextBox([gd3]) do gd3
    return  "gd3   T: $(gd3[:T])\n" *
            "gd3 val: $(gd3[:val])"
end

# ? Starting value decides the type.
gd4 = GenericDependent(Vec3D(0.0,0.0,0.0),[p1]) do p1
    return p1[:xyz]
end

txt4 = TextBox([gd4]) do gd4
    return  "gd4   T: $(gd4[:T])\n" *
            "gd4 val: $(gd4[:val])"
end

play!()
