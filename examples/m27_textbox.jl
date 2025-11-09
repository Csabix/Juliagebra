using Juliagebra

App()

txt1 = TextBox()

p1 = Point(0,0,0)



txt2 = TextBox("Some sample text, which will be\n" * 
               "displayed from the start."
)

p2 = Point([txt2]) do txt2
    if (txt2[:text] == "corner")
        return (5,5,5)
    end

    return nothing
end

p3 = Point(-5,-5,-5)

txt3 = TextBox([p3]) do p3
    return ("$(p3[:x])  - $(p3[:y]) - $(p3[:z])")
end

p4 = Point([txt3]) do txt3
    println(txt3[:text])
    return nothing
end

play!()