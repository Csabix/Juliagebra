using Juliagebra
using JuliaGLM

App()

# ? SourceValueHolder:
# ? Starting value decides the type
# ? so T will be the type of "96.0".
gd1 = ValueHolder(96.0)

txt1 = TextBox([gd1]) do gd1
    return  "gd1   T: $(typeof(gd1))\n" *
            "gd1 val: $(gd1)"
end

p1 = Point(0,0,0)

# ? GenericValueHolder:
# ? T parametric input decides the type.
gd2 = ValueHolder(Vec3D,[p1]) do p1
    return p1
end

txt2 = TextBox([gd2]) do gd2
    return  "gd2   T: $(typeof(gd2))\n" *
            "gd2 val: $(gd2)"
end

# ? UnaryValueHolder:
# ? Unary values can communicate "backwards".
txt3 = ValueHolder(Ref("Alma")) do unary
    TextBox([unary,gd2]) do unary, gd2
        old_unary = unary[]
        unary[] = "Barack"
        return "$(gd2) - $(old_unary)"
    end
end

play!()


