
# ? ---------------------------------
# ! PointDependent
# ? ---------------------------------

mutable struct PointDependent <: RenderedDependentDNA
    _renderedDependent::RenderedDependent
    _coord::Vec3D

    # YELLOW Thread
    function PointDependent(callback::Function,dependents::Vector{<:DependentDNA})
        renderedDependent = RenderedDependent(callback,dependents)
        coord = Vec3DNan
        new(renderedDependent,coord)
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
    push!(self._refs, add!(self._renderers.point,Vec3F(point._coord),POINT_NONE,Vec3F(1.0,0.0,1.0),UInt8(25),aID))
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
Point(x::Real,y::Real,z::Real)::PointDependent =
build!(PointDependent(() -> (return Vec3D(x,y,z)),Vector{DependentDNA}()))

# YELLOW Thread
Point(callback::Function,dependents::Vector{<:DependentDNA}) = 
build!(PointDependent(callback,dependents))

# YELLOW Thread
macro Point(callback::Expr)
    callback = _validate_callback_expr(callback, 0)
    return _create_ctor_wrapper(callback, __module__, Juliagebra.Point)
end

export Point
export @Point
