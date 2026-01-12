using Juliagebra
using JuliaGLM

App()

# ? Starting value decides the type
# ? so T will be the type of "96.0".
gd1 = GenericDependent(96.0)

txt1 = TextBox([gd1]) do gd1
    return  "gd1   T: $(typeof(gd1))\n" *
            "gd1 val: $(gd1)"
end

# ? {T} parametric input decides the type,
# ? So "96.0" gets converted to "Float32(96.0)"
gd2 = GenericDependent{Float32}(96.0)

txt2 = TextBox([gd2]) do gd2
    return  "gd2   T: $(typeof(gd2))\n" *
            "gd2 val: $(gd2)"
end

p1 = Point(0,0,0)

# ? {T} parametric input decides the type.
gd3 = GenericDependent{Vec3D}([p1]) do p1
    return p1
end

txt3 = TextBox([gd3]) do gd3
    return  "gd3   T: $(typeof(gd3))\n" *
            "gd3 val: $(gd3)"
end

play!()
