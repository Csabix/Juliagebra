const RAY_RANGE = range(0, LINE_N_LENGTH, LINE_N_LENGTH + 1)

# ? ---------------------------------
# ! Ray node
# ? ---------------------------------

struct RayDrawData
    handle::UInt32
    colors::Vector{UInt32}
    style::UInt8
    size::Float32
end

convert_callback_result(::PRay, result::PRay)               = result
convert_callback_result(::PRay, result::Tuple{Vec3D,Vec3D}) = PRay(result[1],result[2])
convert_callback_result(::PRay, ::Nothing)                  = PRay(Vec3DNan,Vec3DNan)

function render_node(ray::PRay, data::RayDrawData, renderers::Dict{DataType,Renderer}, id::UInt32)::RayDrawData
    line_renderer::LineRenderer = renderers[LineRenderer]

    p = ray.p0
    v = normalize(ray.p1 - p)
    values = [p + v * sign(t) * 4^abs(t) for t in RAY_RANGE]

    if data.handle == 0
        handle = add!(line_renderer, values, Iterators.cycle(data.colors), Iterators.cycle(id), data.size, data.style)
        return RayDrawData(handle, data.colors, data.style, data.size)
    else
        update_coords!(line_renderer, data.handle, values)
        return data
    end
end

# ? ---------------------------------
# ! Ray intersection
# ? ---------------------------------

struct PRayOfRay <: PrimitivesOf{PRay}
    ray::PRay
end
PrimitivesOf(self::PRay) = PRayOfRay(self)

Base.length(self::PRayOfRay) = 1
Base.iterate(self::PRayOfRay, index::Integer = 1) = index == 1 ? (self.ray, (index + 1)) : nothing

# ? ---------------------------------
# ! Ray constructors
# ? ---------------------------------

_get_parent_ray(parent::NodeHandle) = parent
_get_parent_ray(parent) = add_node!(Vec3D(parent))

function Ray(callback::Function, parents::Union{Vector{NodeHandle},Nothing}=nothing, color_style::Union{Nothing,String}=nothing;
    color="g", style="-", size::Union{AbstractFloat,Integer}=3.0f0)
    (c, s) = parse_line_colors_style(color_style, color, style)
    draw_data = RayDrawData(UInt32(0), c, s, convert(Float32, size))
    return add_node!(callback, PRay(Vec3DNan,Vec3DNan); draw_data=draw_data, parents=parents)
end

function Ray(p0,p1,color_style::Union{Nothing,String}=nothing;
    color="g",style="-",size::Union{AbstractFloat,Integer}=3.0f0)

    parents = NodeHandle[
        _get_parent_ray(p0),
        _get_parent_ray(p1),
    ]

    return Ray(parents,color_style;color=color,style=style,size=size) do p0,p1
        return (p0,p1)
    end
end

function Ray(line,color_style::Union{Nothing,String}=nothing;
    color="g",style="-",size::Union{AbstractFloat,Integer}=3.0f0)
    
    return Ray([_get_parent_ray(line)],color_style;color=color,style=style,size=size) do line
        return (p0(line),p1(line))
    end
end

export Ray
