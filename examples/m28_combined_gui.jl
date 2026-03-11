using Juliagebra

Juliagebra.Window() do 
    ORDER_FLIPPED = true
    
    if (ORDER_FLIPPED)
        s1 = Slider()
        t1 = Toggle()
        s2 = Slider()
        t2 = Toggle()
    else
        t1 = Toggle()
        s1 = Slider()
        t2 = Toggle()
        s2 = Slider()
    end

    txt1 = TextBox()
    txt2 = TextBox("A sample text\n" *
                   "to see how this looks."
    )
    txt3 = TextBox("Another sample text\n" *
                   "to see how this looks."
    )
    txt4 = TextBox("Small sample text.")
end
