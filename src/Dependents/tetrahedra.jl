
# ? ---------------------------------
# ! Tetrahedra
# ? ---------------------------------

function Tetrahedra(a,b,c,d;
    transparent=false, color=(0.1,0.8,0.2),
    border_style=nothing, border_width=3.0,
    border_color=(0.35,0.6,0.35), border_reversed=false)

    Triangle(a,c,b;transparent=transparent, color=color)
    Triangle(a,b,d;transparent=transparent, color=color)
    Triangle(a,d,c;transparent=transparent, color=color)
    Triangle(b,c,d;transparent=transparent, color=color)

    if !(isnothing(border_style))
        Segment(a,b; type=border_style, width=border_width, color=border_color, reversed=border_reversed)
        Segment(a,c; type=border_style, width=border_width, color=border_color, reversed=border_reversed)
        Segment(a,d; type=border_style, width=border_width, color=border_color, reversed=border_reversed)
        Segment(b,d; type=border_style, width=border_width, color=border_color, reversed=border_reversed)
        Segment(b,c; type=border_style, width=border_width, color=border_color, reversed=border_reversed)
        Segment(c,d; type=border_style, width=border_width, color=border_color, reversed=border_reversed)
    end
end

export Tetrahedra