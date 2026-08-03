const LINE_N_LENGTH = ceil(Int16, log(4, 1000))
const LINE_RANGE = range(-LINE_N_LENGTH, LINE_N_LENGTH, 2*LINE_N_LENGTH + 1)

mutable struct Line
    p0::Vec3D
    p1::Vec3D
    handle::NodeHandle
    
    values::Vector{Vec3D}
    colors::Vector{UInt32}
    style::UInt8
    size::Float32

    function Line(colors::Vector{UInt32},style::UInt8,size::Float32)
        values = Vector{Vec3D}(undef, length(LINE_RANGE))
        new(Vec3DNan, Vec3DNan, UInt32(0), values, colors, style, size)
    end
end

function convert_callback_entry(line::Line)::Tuple{Vec3D,Vec3D}
    println("convert_callback_entry")
    return (line.p0, line.p1)
end

function convert_callback_result(line::Line, result::Tuple{Vec3D,Vec3D})
    println("convert_callback_result")
    line.p0 = Vec3D(result[1])
    line.p1 = Vec3D(result[2])
    return line
end

function convert_result(line::Line, index)
    t = LINE_RANGE[index]
    p = line.p0
    v = normalize(line.p1 - line.p0)

    line.values[index] = p + v * sign(t) * 4^abs(t)
end
function eval_node(element::Line, callback::Function, arguments::Vector{Any})::Any
    (p0,p1) = callback(arguments...)
    element.p0 = p0
    element.p1 = p1

    for index in eachindex(LINE_RANGE)
        convert_result(element,index)
    end
    return element
end

function render_node(line::Line, renderers::Dict{DataType,Renderer}, id::UInt32)::Nothing
    line_renderer::LineRenderer = renderers[LineRenderer]
    if line.handle == 0
        line.handle = add!(line_renderer,line.values,Iterators.cycle(line.colors),Iterators.cycle(id),5.0f0,line.style)
    else
        update_coords!(line_renderer,line.handle,line.values)
    end
    return nothing
end

function Line(callback::Function,parents::Union{Vector{NodeHandle},Nothing}=nothing,color_style::Union{Nothing,String}=nothing;
    color="g",style="-",size=3.0f0)
    (c,s) = parse_line_colors_style(color_style,color,style)
    return add_node!(callback, Line(c,s,size), parents)
end

export Line
