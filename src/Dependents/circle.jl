const CIRCLE_RESOLUTION = 1024
const CIRCLE_RANGE = range(0,2pi,CIRCLE_RESOLUTION)

# ? ---------------------------------
# ! Circle node
# ? ---------------------------------

mutable struct Circle
    primitive::PCircle
    handle::UInt32
    
    values::Vector{Vec3D}
    colors::Vector{UInt32}
    style::UInt8
    size::Float32

    function Circle(colors::Vector{UInt32},style::UInt8,size::Union{AbstractFloat,Integer})
        values = Vector{Vec3D}(undef, CIRCLE_RESOLUTION)
        new(PCircle(Vec3DNan,NaN,Vec3DNan), UInt32(0), values, colors, style, convert(Float32,size))
    end
end

function eval_node(circle::Circle, callback::Function, arguments::Vector{Any})::Any
    (center,radius,normal) = callback(arguments...)
    circle.primitive = PCircle(center,radius,normalize(normal))

    vector = Vec3D(1,0,0)
    if (dot(vector,n(circle)) > 1.0 - F64_ANGULAR_THRESHOLD)
        vector = Vec3D(0,1,0)
    end
    u = normalize(cross(n(circle),vector))
    v = normalize(cross(n(circle),u))
    offset = p0(circle)
    radius = r(circle)
    circle.values = [u * c_angle + v * s_angle for (c_angle, s_angle) in zip(cos.(CIRCLE_RANGE), sin.(CIRCLE_RANGE))] .* radius .+ [offset]

    return circle
end

function render_node(circle::Circle, renderers::Dict{DataType,Renderer}, id::UInt32)::Nothing
    line_renderer::LineRenderer = renderers[LineRenderer]
    if circle.handle == 0
        circle.handle = add!(line_renderer,circle.values,Iterators.cycle(circle.colors),Iterators.cycle(id),circle.size,circle.style)
    else
        update_coords!(line_renderer,circle.handle,circle.values)
    end
    return nothing
end

p0(circle::Circle)::Vec3D  = p0(circle.primitive)
n(circle::Circle)::Vec3D   = n(circle.primitive)
r(circle::Circle)::Float64 = r(circle.primitive)

# ? ---------------------------------
# ! Circle intersection
# ? ---------------------------------

const CIRCLE_DETAIL = 64 # TODO: remove segmentation after intersection rework

struct PCircleOfCircle <: PrimitivesOf{PSegment}
    circle::PCircle
end
PrimitivesOf(self::Circle) = PCircleOfCircle(self.primitive)

Base.length(::PCircleOfCircle) = CIRCLE_DETAIL
function Base.getindex(self::PCircleOfCircle, index::Integer)
    vector = Vec3D(1,0,0)
    if (dot(vector,n(self.circle)) > 1.0 - F64_ANGULAR_THRESHOLD)
        vector = Vec3D(0,1,0)
    end
    u = normalize(cross(n(self.circle),vector))
    v = normalize(cross(n(self.circle),u))
    offset = p0(self.circle)
    radius = r(self.circle)
    
    angle1 = index * 2pi / CIRCLE_DETAIL
    angle2 = (index + 1) * 2pi / CIRCLE_DETAIL
    endpoint1 = u * cos(angle1) * radius + v * sin(angle1) * radius + offset
    endpoint2 = u * cos(angle2) * radius + v * sin(angle2) * radius + offset

    return PSegment(endpoint1,endpoint2)
end
Base.iterate(self::PCircleOfCircle, index::Integer = 1) = index <= CIRCLE_DETAIL ? (self[index], (index + 1)) : nothing

# ? ---------------------------------
# ! Circle constructors
# ? ---------------------------------

function Circle(callback::Function,parents::Union{Vector{NodeHandle},Nothing}=nothing,color_style::Union{Nothing,String}=nothing;
    color="b",style="-",size::Union{AbstractFloat,Integer}=5.0f0)
    
    (c,s) = parse_line_colors_style(color_style,color,style)
    return add_node!(callback,Circle(c,s,size),parents)
end

export Circle
