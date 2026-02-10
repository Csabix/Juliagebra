using Juliagebra

App()

n = 20
segment_length = 2.0
vertical_spacing = 0.5
line_color = (0.2, 0.6, 1.0)
line_width = 6.0f0

types = [
    CURVE_SOLID,
    CURVE_DASHED,
    CURVE_DOTTED,
    CURVE_WAVE,
    CURVE_DASH_DOT,
    CURVE_ARROW
]

for i in 1:n
    for (idx, t) in enumerate(types)
        z_pos = ((i - 1) * length(types) + idx) * vertical_spacing
        p1 = Point(0, 0, z_pos)
        p2 = Point(segment_length, 0, z_pos)
        Segment(p1, p2, color=line_color, type=t, width=line_width)
    end
end

play!()