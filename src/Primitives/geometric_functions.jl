
function Midpoint(pointHandles::NodeHandle...;color_style::Union{Nothing,String}=nothing, # color_style must also be a named parameter here
    color="m",style=".",size=25,axis_constraint=AXIS_NONE)::NodeHandle

    nodes = map(handle -> get_element(handle), pointHandles)
    
    if (all(node -> isa(node, Point), nodes))
        point_sequence = PointSequence(collect(pointHandles);size=20)
        return Point([point_sequence],color_style;color=color,style=style,size=size,axis_constraint=axis_constraint) do ps
            return midpoint(ps)
        end
    else
        return Point([pointHandles...],color_style;color=color,style=style,size=size,axis_constraint=axis_constraint) do nodes...
            return midpoint(nodes...)
        end
    end
end


Distance(handles::NodeHandle...;label="Distance")::NodeHandle =
    add_node!((nodes...) -> distance(nodes...); parents = [handles...],draw_data=ScalarData(label))


ClosestPoint(handles::NodeHandle...;color_style::Union{Nothing,String}=nothing,color="w",style=".",size=25,axis_constraint=AXIS_NONE)::NodeHandle =
    Point((nodes...) -> closest_point(nodes...),[handles...],color_style;color=color,style=style,size=size,axis_constraint=axis_constraint)


PerpendicularLine(handles::NodeHandle...;color_style::Union{Nothing,String}=nothing,color="g",style="-",size::Union{AbstractFloat,Integer}=3.0f0)::NodeHandle =
    Line((nodes...) -> perpendicular_line(nodes...),[handles...],color_style;color=color,style=style,size=size)

PerpendicularPlane(handles::NodeHandle...;color_style::Union{Nothing,String}=nothing,color="g")::NodeHandle =
    Plane((nodes...) -> perpendicular_plane(nodes...),[handles...],color_style;color=color)

function Perpendicular(handles::NodeHandle...;
    color_style::Union{Nothing,String}=nothing,color="g",style="-",size::Union{AbstractFloat,Integer}=3.0f0)::NodeHandle
    
    node1 = get_element(handles[1])
    node2 = get_element(handles[2])

    if (isa(node1, LinePrimitive) && isa(node2, Point) || isa(node1, Point) && isa(node2, PrimitiveWithNormal))
        return PerpendicularLine(handles...;color_style=color_style,color=color,style=style,size=size)
    elseif (isa(node1, Point) && isa(node2, Union{PLine,PRay,PSegment,Point}))
        return PerpendicularPlane(handles...;color_style=color_style,color=color)
    else
        error("Perpendicular not implemented")
    end
end

PerpendicularBisector(A::NodeHandle, B::NodeHandle,color_style::Union{Nothing,String}=nothing;color="g",style="-") =
    Line(perpendicular_bisector,[A,B,add_node!(Vec3D(0,0,1))],color_style;color=color,style=style)


ParallelLine(handles::NodeHandle...;color_style::Union{Nothing,String}=nothing,color="g",style="-",size::Union{AbstractFloat,Integer}=3.0f0)::NodeHandle =
    Line((nodes...) -> parallel_line(nodes...),[handles...],color_style;color=color,style=style,size=size)

ParallelPlane(handles::NodeHandle...;color_style::Union{Nothing,String}=nothing,color="g") =
    Plane((nodes...) -> parallel_plane(nodes...),[handles...],color_style;color=color)

function Parallel(handles::NodeHandle...;
    color_style::Union{Nothing,String}=nothing,color="g",style="-",size::Union{AbstractFloat,Integer}=3.0f0)
    
    node1 = get_element(handles[1])
    node2 = get_element(handles[2])

    if (isa(node1, Point) && isa(node2, Union{PLine,PRay,PSegment,Point}))
        return ParallelLine(handles...;color_style,color=color,style=style,size=size)
    elseif (isa(node1, LinePrimitive) && isa(node2, LinePrimitive) || isa(node1, Point) && isa(node2, PrimitiveWithNormal))
        return ParallelPlane(handles...;color_style=color_style,color=color)
    else
        error("Parallel not implemented")
    end
end


function AngleBisectorPlane(handles::NodeHandle...;external::Bool=false,
    color_style::Union{Nothing,String}=nothing,color="g")
    
    return external ?
        Plane((nodes...) -> angle_bisector_plane_external(nodes...),[handles...],color_style;color=color) :
        Plane((nodes...) -> angle_bisector_plane_internal(nodes...),[handles...],color_style;color=color)
end

function AngleBisector(A::NodeHandle,B::NodeHandle,C::NodeHandle,color_style::Union{Nothing,String}=nothing;color="g",style="-",inner::Bool=true)
    parents = [A,B,B,C]
    inner ? Line(angle_bisector_inner,parents,color_style;color=color,style=style) :
            Line(angle_bisector_outer,parents,color_style;color=color,style=style)
end

function AngleBisector(A1::NodeHandle,A2::NodeHandle,B1::NodeHandle,B2::NodeHandle,color_style::Union{Nothing,String}=nothing;color="g",style="-",inner::Bool=true)
    parents = [A1,A2,B1,B2]
    inner ? Line(angle_bisector_inner,parents,color_style;color=color,style=style) :
            Line(angle_bisector_outer,parents,color_style;color=color,style=style)
end

export Midpoint, Distance, ClosestPoint, PerpendicularLine, PerpendicularPlane, Perpendicular, PerpendicularBisector, ParallelLine, ParallelPlane, Parallel,
    AngleBisectorPlane, AngleBisector

