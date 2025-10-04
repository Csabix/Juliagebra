using Juliagebra

ORDER_FLIPPED = true

App()

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


play!()