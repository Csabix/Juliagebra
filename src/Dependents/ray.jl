const RAY_RANGE = range(0, LINE_N_LENGTH, LINE_N_LENGTH + 1)

# ? ---------------------------------
# ! Ray node
# ? ---------------------------------

mutable struct Ray
    primitive::PRay
    values::Vector{Vec3D} # TODO remove

    function Ray()
        values = Vector{Vec3D}(undef, length(RAY_RANGE))
        new(PRay(Vec3DNan, Vec3DNan), values)
    end
end

struct RayDrawData
    handle::UInt32
    colors::Vector{UInt32}
    style::UInt8
    size::Float32
end

# convert_callback_entry(ray::Ray)::Tuple{Vec3D,Vec3D} = (ray.primitive.p0, ray.primitive.p1)
convert_callback_entry(ray::Ray)::Ray = ray

convert_result(ray::Ray, result::PRay)               = ray.primitive = result
convert_result(ray::Ray, result::Tuple{Vec3D,Vec3D}) = ray.primitive = PRay(result[1],result[2])
convert_result(ray::Ray, ::Nothing)                  = ray.primitive = PRay(Vec3DNan,Vec3DNan)

function eval_node(ray::Ray, callback::Function, arguments::Vector{Any})::Any
    convert_result(ray, callback(arguments...))

    for index in eachindex(RAY_RANGE)
        t = RAY_RANGE[index]
        p = ray.primitive.p0
        v = normalize(ray.primitive.p1 - p)
        ray.values[index] = p + v * sign(t) * 4^abs(t)
    end
    return ray
end

function render_node(ray::Ray, data::RayDrawData, renderers::Dict{DataType,Renderer}, id::UInt32)::RayDrawData
    line_renderer::LineRenderer = renderers[LineRenderer]
    if data.handle == 0
        handle = add!(line_renderer, ray.values, Iterators.cycle(data.colors), Iterators.cycle(id), data.size, data.style)
        return RayDrawData(handle, data.colors, data.style, data.size)
    else
        update_coords!(line_renderer, data.handle, ray.values)
        return data
    end
end

p0(ray::Ray)::Vec3D = p0(ray.primitive)
p1(ray::Ray)::Vec3D = p1(ray.primitive)
v(ray::Ray)::Vec3D  = v(ray.primitive)
ClampParameter(ray::Ray,t) = ClampParameter(ray.primitive,t)

# ? ---------------------------------
# ! Ray intersection
# ? ---------------------------------

struct PRayOfRay <: PrimitivesOf{PRay}
    ray::PRay
end
PrimitivesOf(self::Ray) = PRayOfRay(self.primitive)

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
    return add_node!(callback, Ray(); draw_data=draw_data, parents=parents)
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
export p0,p1,v
