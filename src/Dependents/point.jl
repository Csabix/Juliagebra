
# ? ---------------------------------
# ! PointDependent
# ? ---------------------------------

mutable struct PointDependent <: RenderedDependentDNA
    _renderedDependent::RenderedDependent
    _coord::Vec3D
    _color::Vec3F
    _point_type::UInt32
    _size::UInt8

    # YELLOW Thread
    function PointDependent(callback::Function,dependents::Vector{<:DependentDNA};
                            color="m", size::Integer=25, type::Integer=POINT_NONE)
        renderedDependent = RenderedDependent(callback,dependents)
        coord = Vec3DNan
        new(renderedDependent,coord,get_color_vec3f(color),UInt32(type),UInt8(size))
    end
end

_RenderedDependent_(self::PointDependent)::RenderedDependent = return self._renderedDependent
Base.string(self::PointDependent) = "Point[$(_Dependent_(self)._graphID) - $(string(length(_Dependent_(self)._graphParents))) - $(string(length(_Dependent_(self)._graphChain)))]($(self._x),$(self._y),$(self._z))"

function set(self::PointDependent,x::Float64,y::Float64,z::Float64)
    self._coord = Vec3D(x,y,z)
    evalGraph(self)
end

# YELLOW Thread
# RED Thread
onNodeEval(self::PointDependent) = evalCallbackDp(self)

evalCallbackDpEntry(self::PointDependent)::Vec3D = self._coord

evalCallbackDpReturn(self::PointDependent,value) = self._coord = Vec3D(value)
evalCallbackDpReturn(self::PointDependent,value::Tuple) = self._coord = Vec3D(value...)
evalCallbackDpReturn(self::PointDependent,value::Vector) = self._coord = Vec3D(value...)
evalCallbackDpReturn(self::PointDependent,value::Vec3F) = self._coord = Vec3D(value)
evalCallbackDpReturn(self::PointDependent,value::Vec3D) = self._coord = value
evalCallbackDpReturn(self::PointDependent,::Nothing) = self._coord = Vec3DNan

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
    push!(self._refs, add!(self._renderers.point,Vec3F(point._coord),point._point_type,point._color,point._size,aID))
end

# GREEN Thread
function sync!(self::Points,point::PointDependent)
    ref = self._refs[getObserverID(point)]
    aID = UInt32(getGraphID(point) + ID_LOWER_BOUND)
    update_coords!(self._renderers.point,ref,Vec3F(point._coord))
    update_properties(self._renderers.point,ref,point._point_type,point._color,point._size,aID)
end

# GREEN Thread
function destroy!(self::Points) end

# YELLOW Thread
Dependent2Observer(app::AppDNA,::PointDependent) = getDependentObservers(app)[_POINTS]

# ? ---------------------------------
# ! Point
# ? ---------------------------------

# YELLOW Thread
Point(x::Real,y::Real,z::Real; color="m", size::Integer=25, type::Integer=POINT_NONE)::PointDependent =
build!(PointDependent(() -> (return Vec3D(x,y,z)),Vector{DependentDNA}(); color=color, size=size, type=type))

# YELLOW Thread
Point(callback::Function,dependents::Vector{<:DependentDNA}; color="m", size::Integer=25, type::Integer=POINT_NONE) =
build!(PointDependent(callback,dependents; color=color, size=size, type=type))

# YELLOW Thread
macro Point(callback::Expr, kw_args...)
    parsed_kw_args = _parse_macro_kw_args([:color, :size, :type], kw_args...)
    callback = _validate_callback_expr(callback, 0)
    return _create_ctor_wrapper(callback, __module__, Juliagebra.Point; parsed_kw_args...)
end

export Point
export @Point
