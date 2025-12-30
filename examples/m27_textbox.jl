using Juliagebra

App()

txt1 = TextBox()

txt2 = TextBox("Some sample text, which will be\n" * 
               "displayed from the start."
)

p2 = Point([txt2]) do txt2
    if (txt2 == "corner")
        return (5,5,5)
    end

    return nothing
end

p3 = Point(0,0,0)

txt3 = TextBox([p3]) do p3
    return ("$(p3.x)  - $(p3.y) - $(p3.z)")
end

p4 = Point([txt3]) do txt3
    println(txt3)
    return nothing
end

play!()