const RAY_RANGE = range(0, LINE_N_LENGTH, LINE_N_LENGTH + 1)

# ? ---------------------------------
# ! Ray node
# ? ---------------------------------

mutable struct Ray
    primitive::PRay
    handle::NodeHandle
    
    range::AbstractRange{Float64}
    values::Vector{Vec3D}
    colors::Vector{UInt32}
    style::UInt8
    size::Float32

    function Ray(primitive::PRay,colors::Vector{UInt32},style::UInt8,size::Float32)
        range = RAY_RANGE
        values = Vector{Vec3D}(undef, length(range))
        new(primitive, UInt32(0), range, values, colors, style, size)
    end
end

# convert_callback_entry(ray::Ray)::Tuple{Vec3D,Vec3D} = (ray.primitive.p0, ray.primitive.p1)
convert_callback_entry(ray::Ray)::Ray = ray

convert_result(ray::Ray, result::PRay)               = ray.primitive = result
convert_result(ray::Ray, result::Tuple{Vec3D,Vec3D}) = ray.primitive = PRay(result[1],result[2])
convert_result(ray::Ray, ::Nothing)                  = ray.primitive = PRay(Vec3DNan,Vec3DNan)

function eval_node(ray::Ray, callback::Function, arguments::Vector{Any})::Any
    convert_result(ray, callback(arguments...))

    for index in eachindex(ray.range)
        t = ray.range[index]
        p = ray.primitive.p0
        v = normalize(ray.primitive.p1 - p)
        ray.values[index] = p + v * sign(t) * 4^abs(t)
    end
    return ray
end

function render_node(ray::Ray, renderers::Dict{DataType,Renderer}, id::UInt32)::Nothing
    line_renderer::LineRenderer = renderers[LineRenderer]
    if ray.handle == 0
        ray.handle = add!(line_renderer,ray.values,Iterators.cycle(ray.colors),Iterators.cycle(id),ray.size,ray.style)
    else
        update_coords!(line_renderer,ray.handle,ray.values)
    end
    return nothing
end

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

function Ray(callback::Function,parents::Union{Vector{NodeHandle},Nothing}=nothing,color_style::Union{Nothing,String}=nothing;
    color="g",style="-",size=3.0f0)
    (c,s) = parse_line_colors_style(color_style,color,style)
    return add_node!(callback, Ray(PRay(Vec3DNan,Vec3DNan),c,s,size), parents)
end

function Ray(p0,p1,color_style::Union{Nothing,String}=nothing;
    color="g",style="-",size=3.0f0)

    parents = NodeHandle[
        _get_parent_ray(p0),
        _get_parent_ray(p1),
    ]

    (c,s) = parse_line_colors_style(color_style,color,style)
    return add_node!(Ray(PRay(Vec3DNan,Vec3DNan),c,s,size), parents) do p0,p1
        return (p0,p1)
    end
end

export Ray
