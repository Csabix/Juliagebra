
# ? ---------------------------------
# ! Tetrahedra
# ? ---------------------------------

function Tetrahedra(a,b,c,d,color_data::Union{Nothing,String}=nothing;
    color="g",
    border_color="c",border_style="-",border_size=3.0)

    Triangle(a,c,b,color_data;color=color)
    Triangle(a,b,d,color_data;color=color)
    Triangle(a,d,c,color_data;color=color)
    Triangle(b,c,d,color_data;color=color)

    if !(isnothing(border_style))
        Segment(a,b; color=border_color, style=border_style, size=border_size)
        Segment(a,c; color=border_color, style=border_style, size=border_size)
        Segment(a,d; color=border_color, style=border_style, size=border_size)
        Segment(b,d; color=border_color, style=border_style, size=border_size)
        Segment(b,c; color=border_color, style=border_style, size=border_size)
        Segment(c,d; color=border_color, style=border_style, size=border_size)
    end
end

export Tetrahedra