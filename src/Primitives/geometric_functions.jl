
function Midpoint(pointHandles::NodeHandle...;color_style::Union{Nothing,String}=nothing, # color_style must also be a named parameter here
    color="m",style=".",size=25,axis_constraint=AXIS_NONE)::NodeHandle

    nodes = map(handle -> get_element(handle), pointHandles)
    
    if (all(node -> isa(node, Point), nodes))
        point_sequence = PointSequence(collect(pointHandles))
        return Point([point_sequence],color_style;color=color,style=style,size=size,axis_constraint=axis_constraint) do ps
            return midpoint(ps)
        end
    else
        return Point([pointHandles...],color_style;color=color,style=style,size=size,axis_constraint=axis_constraint) do nodes...
            return midpoint(nodes...)
        end
    end
end


Distance(handles::NodeHandle...)::NodeHandle = add_node!((nodes...) -> distance(nodes...), [handles...])


ClosestPoint(handles::NodeHandle...;color_style::Union{Nothing,String}=nothing,color="w",style=".",size=25,axis_constraint=AXIS_NONE)::NodeHandle =
    Point((nodes...) -> closest_point(nodes...),[handles...],color_style;color=color,style=style,size=size,axis_constraint=axis_constraint)


PerpendicularLine(handles::NodeHandle...;color_style::Union{Nothing,String}=nothing,color="g",style="-",size::Union{AbstractFloat,Integer}=3.0f0)::NodeHandle =
    Line((nodes...) -> perpendicular_line(nodes...),[handles...],color_style;color=color,style=style,size=size)

PerpendicularPlane(handles::NodeHandle...;color_style::Union{Nothing,String}=nothing,color="g")::NodeHandle =
    Plane((node...) -> perpendicular_plane(node...),[handles...],color_style;color=color)

function Perpendicular(handles::NodeHandle...;
    color_style::Union{Nothing,String}=nothing,color="g",style="-",size::Union{AbstractFloat,Integer}=3.0f0)::NodeHandle
    
    node1 = get_element(handles[1])
    node2 = get_element(handles[2])

    if (isa(node1, Union{Line,Ray,Segment}) && isa(node2, Point) || isa(node1, Point) && isa(node2, Union{Plane,Circle}))
        return PerpendicularLine(handles...;color_style=color_style,color=color,style=style,size=size)
    elseif (isa(node1, Point) && isa(node2, Union{Line,Ray,Segment,Point}))
        return PerpendicularPlane(handles...;color_style=color_style,color=color)
    else
        error("Perpendicular not implemented")
    end
end


ParallelLine(handles::NodeHandle...;color_style::Union{Nothing,String}=nothing,color="g",style="-",size::Union{AbstractFloat,Integer}=3.0f0)::NodeHandle =
    Line((nodes...) -> parallel_line(nodes...),[handles...],color_style;color=color,style=style,size=size)

ParallelPlane(handles::NodeHandle...;color_style::Union{Nothing,String}=nothing,color="g") =
    Plane((nodes...) -> parallel_plane(nodes...),[handles...],color_style;color=color)

function Parallel(handles::NodeHandle...;
    color_style::Union{Nothing,String}=nothing,color="g",style="-",size::Union{AbstractFloat,Integer}=3.0f0)
    
    node1 = get_element(handles[1])
    node2 = get_element(handles[2])

    if (isa(node1, Point) && isa(node2, Union{Line,Ray,Segment,Point}))
        return ParallelLine(handles...;color_style,color=color,style=style,size=size)
    elseif (isa(node1, Union{Line,Ray,Segment}) && isa(node2, Union{Line,Ray,Segment}) || isa(node1, Point) && isa(node2, Union{Plane,Circle}))
        return ParallelPlane(handles...;color_style=color_style,color=color)
    else
        error("Parallel not implemented")
    end
end



export Midpoint, Distance, ClosestPoint, PerpendicularLine, PerpendicularPlane, Perpendicular, ParallelLine, ParallelPlane, Parallel

