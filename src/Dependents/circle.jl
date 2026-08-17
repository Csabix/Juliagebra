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

_get_parent_circle(parent::NodeHandle) = parent
_get_parent_circle(parent::Number) = add_node!(parent)
_get_parent_circle(parent) = add_node!(Vec3D(parent))

function Circle(callback::Function,parents::Union{Vector{NodeHandle},Nothing}=nothing,color_style::Union{Nothing,String}=nothing;
    color="b",style="-",size::Union{AbstractFloat,Integer}=5.0f0)
    
    (c,s) = parse_line_colors_style(color_style,color,style)
    return add_node!(callback,Circle(c,s,size),parents)
end
function Circle(data1,data2,data3=nothing,color_style::Union{Nothing,String}=nothing;
    color="b",style="-",size::Union{AbstractFloat,Integer}=5.0f0)
    
    parents = NodeHandle[
        _get_parent_circle(data1),
        _get_parent_circle(data2),
    ]
    if (data3 !== nothing)
        push!(parents, _get_parent_circle(data3))
    end

    node1 = get_element(parents[1])
    node2 = get_element(parents[2])
    node3 = data3 !== nothing ? get_element(parents[3]) : nothing

    create_circle(node1,node2,node3,parents,
        color_style;color=color,style=style,size=size)
end

function create_circle(::Union{Point,Vec3D},::Union{Point,Vec3D},::Union{Point,Vec3D},
    parents::Vector{NodeHandle},color_style::Union{Nothing,String}=nothing;
    color="b",style="-",size::Union{AbstractFloat,Integer}=5.0f0)
    
    # https://en.wikipedia.org/wiki/Circumcircle#Cartesian_coordinates_from_cross-_and_dot-products
    return Circle(parents,color_style;color=color,style=style,size=size) do p1,p2,p3
        p12 = p1 - p2
        p13 = p1 - p3
        p23 = p2 - p3
        normal = cross(p12,p23)
        if (norm(normal) < F64_LINEAR_THRESHOLD) return (Vec3DNan,NaN,Vec3DNan) end

        divisor = 2 * dot(normal,normal)
        alpha = dot(p23,p23) * dot(p12,p13)   / divisor
        beta  = dot(p13,p13) * dot(-p12,p23)  / divisor
        gamma = dot(p12,p12) * dot(-p13,-p23) / divisor
        center = p1 * alpha + p2 * beta + p3 * gamma

        radius = norm(p12) * norm(p23) * norm(p13) / (2 * norm(normal))

        return (center,radius,normal)
    end
end
function create_circle(::Union{Line,Ray,Segment},::Union{Point,Vec3D},::Nothing,
    parents::Vector{NodeHandle},color_style::Union{Nothing,String}=nothing;
    color="b",style="-",size::Union{AbstractFloat,Integer}=5.0f0)
    
    return Circle(parents,color_style;color=color,style=style,size=size) do line,point
        projected = project_to_line(point,line)
        radius = distance(point,projected)
        return (projected,radius,v(line))
    end
end
function create_circle(::Union{Point,Vec3D},::Union{Point,Vec3D},plane::Union{Plane,Nothing},
    parents::Vector{NodeHandle},color_style::Union{Nothing,String}=nothing;
    color="b",style="-",size::Union{AbstractFloat,Integer}=5.0f0)
    
    if (plane !== nothing)
        return Circle((c,p,plane) -> _circle_callback_2_coords_1_plane(c,p,plane),
            parents,color_style;color=color,style=style,size=size)
    else
        return Circle((c,p) -> _circle_callback_2_coords_1_plane(c,p),
            parents,color_style;color=color,style=style,size=size)
    end
end
function create_circle(::Union{Point,Vec3D},::Number,plane::Union{Plane,Nothing},
    parents::Vector{NodeHandle},color_style::Union{Nothing,String}=nothing;
    color="b",style="-",size::Union{AbstractFloat,Integer}=5.0f0)
    
    if (plane !== nothing)
        return Circle((c,n,plane) -> _circle_callback_1_coord_1_scalar_1_plane(c,n,plane),
            parents,color_style;color=color,style=style,size=size)
    else
        return Circle((c,n) -> _circle_callback_1_coord_1_scalar_1_plane(c,n),
            parents,color_style;color=color,style=style,size=size)
    end
end

function _circle_callback_2_coords_1_plane(center::Vec3D,point::Vec3D,plane::Union{Plane,Nothing}=nothing)::Tuple{Vec3D,Float64,Vec3D}
    if (plane !== nothing)
        normal = n(plane)
    else
        normal = n(DefaultPlane)
    end
    dist = dot(normal,point - center)
    point_on_plane = point - dist * normal
    if (abs(dist) > DISTANCE_EPSILON) @log("Point of circle isn't on the circle's given plane!", WARN) end
    return (center,distance(center,point_on_plane),normal)
end
function _circle_callback_1_coord_1_scalar_1_plane(center::Vec3D,radius::Float64,plane::Union{Plane,Nothing}=nothing)::Tuple{Vec3D,Float64,Vec3D}
    return (center,radius,plane !== nothing ? normal = n(plane) : normal = n(DefaultPlane))
end


export Circle
