
# ? ---------------------------------
# ! Segment
# ? ---------------------------------

_get_dependent_segment(dep::DependentDNA) = dep
_get_dependent_segment(dep) = SourceValueHolder(Vec3D(dep))

function Segment(p0,p1,color_style::Union{Nothing,String}=nothing;
                 color="c",style="-",size=5.0f0)
    deps = DependentDNA[
        _get_dependent_segment(p0),
        _get_dependent_segment(p1)
    ]
    # × return
    ParametricCurve(range(0,1,length=2),deps,color_style;color=color,style=style,size=size) do t,p0,p1
        return p1 .* t .+ (1-t) .* p0
    end

    return ValueHolder(PSegment, deps) do p1,p2
        return PSegment(p1,p2)
    end
end

function Segment(callback::Function,dependents::Vector{<:DependentDNA}=DependentDNA[],color_style::Union{Nothing,String}=nothing;
                 color="c",style="-",size=5.0f0)
    
    ParametricCurve(range(0,1,length=2),dependents,color_style;color=color,style=style,size=size) do t,param
        psegment = callback(param)
        if (psegment === nothing) return nothing end
        
        return psegment.p1 .* t .+ (1-t) .* psegment.p0
    end
end

function Segment(line,color_style::Union{Nothing,String}=nothing;
    color="g",style="-",size=3.0f0)
    
    Segment([line],color_style;color=color,style=style,size=size) do l
        return PSegment(p(l),p(l) + v(l))
    end
end

# ? ---------------------------------
# ! Segment to PSegment intersection
# ? ---------------------------------

struct PSegmentOfSegment <: PrimitivesOf{PSegment}
    segment::PSegment
end
PrimitivesOf(self::PSegment) = PSegmentOfSegment(self)

Base.length(self::PSegmentOfSegment) = 1
Base.iterate(self::PSegmentOfSegment, index::Integer = 1) = index == 1 ? (self.segment, (index + 1)) : nothing

export Segment
