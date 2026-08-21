const CIRCLE_RESOLUTION = 1024
const CIRCLE_RANGE = range(0,2pi,CIRCLE_RESOLUTION)

# ? ---------------------------------
# ! Circle node
# ? ---------------------------------

mutable struct CircleDrawData
    handle::LineHandle
    colors::Vector{UInt32}
    style::UInt8
    size::Float32
end

convert_callback_result(::PCircle, result::PCircle)                    = result
convert_callback_result(::PCircle, result::Tuple{Vec3D,Float64,Vec3D}) = PCircle(result[1],result[2],normalize(result[3]))
convert_callback_result(::PCircle, ::Nothing)                          = PCircle(Vec3DNan,NaN64,Vec3DNan)

function render_node(circle::PCircle, data::CircleDrawData, renderers::Dict{DataType,Renderer}, id::UInt32)::CircleDrawData
    line_renderer::LineRenderer = renderers[LineRenderer]

    u = normalize(perpendicular_vector(n(circle)))
    v = normalize(cross(n(circle),u))
    offset = p0(circle)
    radius = r(circle)
    values = [u * c_angle + v * s_angle for (c_angle, s_angle) in zip(cos.(CIRCLE_RANGE), sin.(CIRCLE_RANGE))] .* radius .+ [offset]

    if is_null(data.handle)
        data.handle = add!(line_renderer,values,data.colors,[id],data.style,data.size)
    else
        @inbounds update_coords!(line_renderer,data.handle,values)
    end
    return data
end

# ? ---------------------------------
# ! Circle intersection
# ? ---------------------------------

const CIRCLE_SEGMENTATION_DETAIL = 64 # TODO: remove segmentation after intersection rework

struct PCircleOfCircle <: PrimitivesOf{PSegment}
    circle::PCircle
    u::Vec3D
    v::Vec3D
end
function PrimitivesOf(self::PCircle)::PCircleOfCircle
    u = normalize(perpendicular_vector(n(self)))
    v = normalize(cross(n(self),u))
    return PCircleOfCircle(self,u,v)
end

Base.length(::PCircleOfCircle) = CIRCLE_SEGMENTATION_DETAIL
function Base.getindex(self::PCircleOfCircle, index::Integer)
    angle1 = index * 2pi / CIRCLE_SEGMENTATION_DETAIL
    angle2 = (index + 1) * 2pi / CIRCLE_SEGMENTATION_DETAIL
    radius = r(self.circle)
    offset = p0(self.circle)
    endpoint1 = self.u * cos(angle1) * radius + self.v * sin(angle1) * radius + offset
    endpoint2 = self.u * cos(angle2) * radius + self.v * sin(angle2) * radius + offset

    return PSegment(endpoint1,endpoint2)
end
Base.iterate(self::PCircleOfCircle, index::Integer = 1) = index <= CIRCLE_SEGMENTATION_DETAIL ? (self[index], (index + 1)) : nothing

# ? ---------------------------------
# ! Circle constructors
# ? ---------------------------------

_get_parent_circle(parent::NodeHandle) = parent
_get_parent_circle(parent::Number) = add_node!(parent)
_get_parent_circle(parent) = add_node!(Vec3D(parent))

function Circle(callback::Function,parents::Union{Vector{NodeHandle},Nothing}=nothing,color_style::Union{Nothing,String}=nothing;
    color="b",style="-",size::Union{AbstractFloat,Integer}=5.0f0)
    
    (c,s) = parse_line_colors_style(color_style,color,style)
    draw_data = CircleDrawData(LineHandle(),c,s,convert(Float32,size))
    return add_node!(callback,PCircle(Vec3DNan,NaN64,Vec3DNan);draw_data=draw_data,parents=parents)
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

        return (center,radius,normalize(normal))
    end
end
function create_circle(::LinePrimitive,::Union{Point,Vec3D},::Nothing,
    parents::Vector{NodeHandle},color_style::Union{Nothing,String}=nothing;
    color="b",style="-",size::Union{AbstractFloat,Integer}=5.0f0)
    
    return Circle(parents,color_style;color=color,style=style,size=size) do line,point
        projected = project_to_line(point,line)
        radius = distance(point,projected)
        return (projected,radius,normalize(v(line)))
    end
end
function create_circle(::Union{Point,Vec3D},::Union{Point,Vec3D},plane::Union{PPlane,Nothing},
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
function create_circle(::Union{Point,Vec3D},::Number,plane::Union{PPlane,Nothing},
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

function _circle_callback_2_coords_1_plane(center::Vec3D,point::Vec3D,plane::Union{PPlane,Nothing}=nothing)::Tuple{Vec3D,Float64,Vec3D}
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
function _circle_callback_1_coord_1_scalar_1_plane(center::Vec3D,radius::Float64,plane::Union{PPlane,Nothing}=nothing)::Tuple{Vec3D,Float64,Vec3D}
    return (center,radius,normalize(plane !== nothing ? n(plane) : n(DefaultPlane)))
end


export Circle
