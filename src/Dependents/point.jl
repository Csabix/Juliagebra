
# ? ---------------------------------
# ! PointDependent
# ? ---------------------------------

mutable struct PointDependent <: RenderedDependentDNA
    _renderedDependent::RenderedDependent
    _coord::Vec3D
    _color::UInt32
    _style::UInt8
    _size::UInt8
    _constraints::UInt8

    # YELLOW Thread
    function PointDependent(callback::Function,dependents::Vector{<:DependentDNA},
                            color::UInt32,style::UInt8,size::UInt8,axis_constraint::UInt32)
        dependent = RenderedDependent(callback,dependents)
        coord = Vec3DNan
        new(dependent,coord,color,style,UInt8(size),UInt8(axis_constraint))
    end
end

_RenderedDependent_(self::PointDependent)::RenderedDependent = return self._renderedDependent
Base.string(self::PointDependent) = "Point[$(_Dependent_(self)._graphID) - $(string(length(_Dependent_(self)._graphParents))) - $(string(length(_Dependent_(self)._graphChain)))]($(self._x),$(self._y),$(self._z))"

# YELLOW Thread
# RED Thread
onNodeEval(self::PointDependent) = evalCallbackDp(self)

Base.eltype(dependent::PointDependent)::DataType = Vec3D
evalCallbackDpEntry(self::PointDependent)::Vec3D = self._coord

evalCallbackDpReturn(self::PointDependent,value) = self._coord = Vec3D(value)
evalCallbackDpReturn(self::PointDependent,value::Tuple) = self._coord = Vec3D(value...)
evalCallbackDpReturn(self::PointDependent,value::Vector) = self._coord = Vec3D(value...)
evalCallbackDpReturn(self::PointDependent,value::Vec3F) = self._coord = Vec3D(value)
evalCallbackDpReturn(self::PointDependent,value::Vec3D) = self._coord = value
evalCallbackDpReturn(self::PointDependent,::Nothing) = self._coord = Vec3DNan

edit_dependent_overload(::PointDependent)::Bool = true
function edit_dependent(point::PointDependent,model::Model,renderers::PrimitiveRenderers)::Nothing
    id = getGraphID(point)
    coord = point._coord
    x_ref = Ref(Cdouble(coord.x))
    y_ref = Ref(Cdouble(coord.y))
    z_ref = Ref(Cdouble(coord.z))
    invalidate = false
    if CImGui.InputDouble("##x$id", x_ref, 0.0, 0.0, "%.4f")
        point._coord = Vec3D(x_ref[],coord[2],coord[3])
        invalidate = true
    end
    if CImGui.InputDouble("##y$id", y_ref, 0.0, 0.0, "%.4f")
        point._coord = Vec3D(coord[1],y_ref[],coord[3])
        invalidate = true
    end
    if CImGui.InputDouble("##z$id", z_ref, 0.0, 0.0, "%.4f")
        point._coord = Vec3D(coord[1],coord[2],z_ref[])
        invalidate = true
    end
    if invalidate schedule(model,point) end

    new_color = color_edit3(point._color, "##pcol$id")
    if new_color !== nothing
        point._color = new_color
        ref = getObserver(point)._refs[getObserverID(point)]
        update_colors!(renderers.point,ref,new_color)
    end

    _POINT_STYLE_VALUES = [POINT_NONE, POINT_PLUS]
    _POINT_STYLE_LABELS = [".", "+"]
    cur_idx = something(findfirst(==(point._style), _POINT_STYLE_VALUES), 1) - 1
    style_ref = Ref(Cint(cur_idx))
    if CImGui.Combo("##pst$id", style_ref, _POINT_STYLE_LABELS, length(_POINT_STYLE_LABELS))
        point._style = style_ref[]
        ref = getObserver(point)._refs[getObserverID(point)]
        update_styles!(renderers.point,ref,point._style)
    end

    CImGui.TableNextColumn()
    size_ref = Ref(Cint(point._size))
    if CImGui.SliderInt("##psz$id", size_ref, 0, 255)
        point._size = UInt8(size_ref[])
        ref = getObserver(point)._refs[getObserverID(point)]
        update_sizes!(renderers.point,ref,point._size)
    end
    return nothing
end

# ? ---------------------------------
# ! Points
# ? ---------------------------------

mutable struct Points <:RendererDNA{PointDependent}
    _renderer::Renderer{PointDependent}
    _renderers::PrimitiveRenderers
    _refs::Vector{UInt32}

    # GREEN Thread
    function Points(context::OpenGLData)
        renderer = Renderer{PointDependent}(context)
        refs = Vector{UInt32}()
        new(renderer, context._renderers, refs)
    end
end

_Renderer_(self::Points) = return self._renderer
Base.string(self::Points) = return "Points($(length(self._refs)))"

# GREEN Thread
function added!(self::Points,point::PointDependent)
    aID = UInt32(getGraphID(point) + ID_LOWER_BOUND)
    ref = add!(self._renderers.point,Vec3F(point._coord),point._color,point._style,point._size,aID)
    push!(self._refs, ref)
end

# GREEN Thread
function sync!(self::Points,point::PointDependent)
    ref = self._refs[getObserverID(point)]
    update_coords!(self._renderers.point,ref,Vec3F(point._coord))
end

# GREEN Thread
function destroy!(self::Points) end

# YELLOW Thread
Dependent2Observer(app::AppDNA,::PointDependent) = getDependentObservers(app)[_POINTS]

# ? ---------------------------------
# ! Point
# ? ---------------------------------

# YELLOW Thread
function Point(callback::Function,dependents::Vector{<:DependentDNA}=DependentDNA[],color_style::Union{Nothing,String}=nothing;
    color="m",style=".",size=25,axis_constraint=AXIS_NONE)
    (c,s) = parse_point_color_style(color_style,color,style)
    Build!(PointDependent(callback,dependents,c,s,round(UInt8,size),axis_constraint))
end

# YELLOW Thread
Point(x::Real,y::Real,z::Real,color_style::Union{Nothing,String}=nothing;
    color="m",style=".",size=25,axis_constraint=AXIS_X|AXIS_Y|AXIS_Z)::PointDependent =
Point(() -> Vec3D(x,y,z),DependentDNA[],color_style,color=color,style=style,size=size,axis_constraint=axis_constraint)

Point(x::Real,y::Real,color_style::Union{Nothing,String}=nothing;
    color="m",style=".",size=25,axis_constraint=AXIS_X|AXIS_Y)::PointDependent =
Point(() -> Vec3D(x,y,0.0),DependentDNA[],color_style,color=color,style=style,size=size,axis_constraint=axis_constraint)

# YELLOW Thread
macro Point(callback::Expr, args...)
    (positional_args, kw_args) = _parse_macro_arguments((:color_style,),(:color, :style, :size, :axis_constraint), args...)
    callback = _validate_callback_expr(callback, 0)
    return _create_ctor_wrapper(callback, __module__, Juliagebra.Point,
                                positional_args, kw_args)
end

export Point
export @Point
