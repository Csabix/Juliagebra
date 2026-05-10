using Juliagebra

Juliagebra.Window() do 
    
    s1 = Slider(label="A slider with a label")
    t1 = Toggle(label="A toggle with a label")
    s2 = Slider()
    t2 = Toggle()
   

    txt1 = TextBox()
    txt2 = TextBox("A sample text\n" *
                   "to see how this looks."
                   ; label = "A textbox with a label."
    )
    txt3 = TextBox("Another sample text\n" *
                   "to see how this looks."
    )
    txt4 = TextBox("Small sample text.")
end
