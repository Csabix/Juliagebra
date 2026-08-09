
# ? ---------------------------------
# ! Tetrahedra
# ? ---------------------------------

function Tetrahedra(a,b,c,d,color_data::Union{Nothing,String}=nothing;
    color=nothing,
    border_color=nothing,border_style=nothing,border_size=nothing)

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