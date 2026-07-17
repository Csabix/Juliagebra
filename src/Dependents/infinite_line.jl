
# ? ---------------------------------
# ! InfiniteLineDependent
# ? ---------------------------------

mutable struct InfiniteLineDependent <: RenderedDependentDNA
    _renderedDependent::RenderedDependent
    _coord::Vec3D
    _color::UInt32
    _style::UInt8
    _size::UInt8
    _constraints::UInt8

    function InfiniteLineDependent(callback::Function,dependents::Vector{<:DependentDNA},color::UInt32,style::UInt8,size::UInt8,axis_constraint::UInt32)
        dependent = RenderedDependent(callback,dependents)
        coord = Vec3DNan
        new(dependent,coord,color,style,UInt8(size),UInt8(axis_constraint))
    end
end

_RenderedDependent_(self::InfiniteLineDependent)::RenderedDependent = return self._renderedDependent
Base.string(self::InfiniteLineDependent) = "InfiniteLineDependent[$(_Dependent_(self)._graphID) - $(string(length(_Dependent_(self)._graphParents))) - $(string(length(_Dependent_(self)._graphChain)))]($(self._x),$(self._y),$(self._z))"

onNodeEval(self::InfiniteLineDependent) = evalCallbackDp(self)

evalCallbackDpEntry(self::InfiniteLineDependent)::Vec3D = self._coord
evalCallbackDpReturn(self::InfiniteLineDependent,value) = self._coord = Vec3D(value)

# ? ---------------------------------
# ! Infinite Lines
# ? ---------------------------------

mutable struct InfiniteLines <:RendererDNA{InfiniteLineDependent}
    _renderer::Renderer{InfiniteLineDependent}
    _renderers::PrimitiveRenderers
    _refs::Vector{UInt32}

    # GREEN Thread
    function InfiniteLines(context::OpenGLData)
        renderer = Renderer{InfiniteLineDependent}(context)
        refs = Vector{UInt32}()
        new(renderer, context._renderers, refs)
    end
end

_Renderer_(self::InfiniteLines) = return self._renderer
Base.string(self::InfiniteLines) = return "InfiniteLines($(length(self._refs)))"

function added!(self::InfiniteLines,point::InfiniteLineDependent)
    aID = UInt32(getGraphID(point) + ID_LOWER_BOUND)

    # adds PointRenderer to ??? & returns ref id
    ref = add!(self._renderers.point,Vec3F(point._coord),point._color,point._style,point._size,aID)
    println("infline added: ", ref)

    push!(self._refs, ref)
end

function sync!(self::InfiniteLines,point::InfiniteLineDependent)
    ref = self._refs[getObserverID(point)]
    println("infline synced: ", ref)
    update_coords!(self._renderers.point,ref,Vec3F(point._coord))
end

function destroy!(self::InfiniteLines) end

Dependent2Observer(app::AppDNA,::InfiniteLineDependent) = getDependentObservers(app)[_INFINITE_LINES]

# ? ---------------------------------
# ! InfiniteLine
# ? ---------------------------------

function InfiniteLine(callback::Function,dependents::Vector{<:DependentDNA}=DependentDNA[],color_style::Union{Nothing,String}=nothing;
    color="g",style=".",size=25,axis_constraint=AXIS_NONE)
    
    (c,s) = parse_point_color_style(color_style,color,style)
    
    Build!(InfiniteLineDependent(callback,dependents,c,s,round(UInt8,size),axis_constraint))
end

function InfiniteLine(x::Real,y::Real,z::Real,color_style::Union{Nothing,String}=nothing; color="g",style=".",size=25,axis_constraint=AXIS_X|AXIS_Y|AXIS_Z)::InfiniteLineDependent
    return InfiniteLine(() -> Vec3D(x,y,z),DependentDNA[],color_style,color=color,style=style,size=size,axis_constraint=axis_constraint)
end

export InfiniteLine
