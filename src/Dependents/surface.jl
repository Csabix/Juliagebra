mutable struct ParametricSurface{Range<:AbstractRange}
    vertexes::FlatMatrixManager{Vec3F}
    indexes::Vector{UInt32}
    uvValues::FlatMatrix{Vec3D}
    uvNormals::FlatMatrix{Vec3D}

    uRange::Range
    vRange::Range

    color::UInt32
    handle::UInt32

    function ParametricSurface(uRange::Range,vRange::Range,color::UInt32) where {Range<:AbstractRange}
        vertexes = FlatMatrixManager{Vec3F}()
        indexes = Vector{UInt32}()
        uvValues = FlatMatrix{Vec3D}(length(uRange),length(vRange))
        uvNormals = FlatMatrix{Vec3D}(length(uRange),length(vRange))
        new{Range}(vertexes,indexes,uvValues,uvNormals,uRange,vRange,color,UInt32(0))
    end
end

convert_result(ps::ParametricSurface,result,u,v) = (ps.uvValues[u,v] = Vec3D(result);ps)
convert_result(ps::ParametricSurface,result::Tuple,u,v) = (ps.uvValues[u,v] = Vec3D(result...);ps)
convert_result(ps::ParametricSurface,result::Vec3F,u,v) = (ps.uvValues[u,v] = Vec3D(result);ps)
convert_result(ps::ParametricSurface,result::Vec3D,u,v) = (ps.uvValues[u,v] = result;ps)
convert_result(ps::ParametricSurface,::Nothing,u,v) = (ps.uvValues[u,v] = Vec3DNan;ps)

function setNormal!(element::ParametricSurface, u::Int, v::Int, w::Int, h::Int)
    vals = element.uvValues

    right = vals[min(u + 1, w), v]
    left  = vals[max(u - 1, 1), v]
    down  = vals[u, min(v + 1, h)]
    up    = vals[u, max(v - 1, 1)]

    uVec = right - left
    vVec = down - up
    element.uvNormals[u, v] = normalize(cross(uVec, vVec))
end

function eval_node(element::ParametricSurface, callback::Function, arguments::Vector{Any})::Any
    for (v, vf) in enumerate(element.vRange), (u, uf) in enumerate(element.uRange)
        res = callback(uf, vf, arguments...)
        convert_result(element, res, u, v)
    end
    
    w = width(element.uvValues)
    h = height(element.uvValues)
    for v in 1:h, u in 1:w
        setNormal!(element, u, v, w, h)
    end

    return element
end

function render_node(ps::ParametricSurface, renderers::Dict{DataType,Renderer}, id::UInt32)::Nothing
    triangle_renderer::TriangleRenderer = renderers[TriangleRenderer]
    if ps.handle == 0
        width = length(ps.uRange)
        height = length(ps.vRange)
        initMatrix(ps.vertexes,width,height,Vec3FNan)
        triangulateInto!(ps.indexes,ps.vertexes,layers(ps.vertexes))
        copy!(ps.uvValues,ps.vertexes,layers(ps.vertexes))
        triangles = get_triangulated(data(ps.vertexes, layers(ps.vertexes)),ps.vertexes,layers(ps.vertexes))
        ps.handle = add!(triangle_renderer,triangles,mat4(1.0f0),ps.color,false,id)
    else
        copy!(ps.uvValues,ps.vertexes,layers(ps.vertexes))
        triangles = get_triangulated(data(ps.vertexes, layers(ps.vertexes)),ps.vertexes,layers(ps.vertexes))
        update_coords!(triangle_renderer,ps.handle,triangles)
    end
    return nothing
end

# ? For Intersectable ParametricSurfaces.
struct PTrianglesOfSurface <: PrimitivesOf{PTriangle}
    _surfaceTriangleIterator::TrianglesOf
end
PrimitivesOf(self::ParametricSurface) = return PTrianglesOfSurface(TrianglesOf(self.uvValues))
Base.length(self::PTrianglesOfSurface) = return length(self._surfaceTriangleIterator)
Base.getindex(self::PTrianglesOfSurface, index::UInt)::PTriangle = return self._surfaceTriangleIterator[index]
Base.iterate(self::PTrianglesOfSurface, state = (1,1,1)) = return iterate(self._surfaceTriangleIterator,state)   

# ? ---------------------------------
# ! ParametricSurfaceRenderer
# ? ---------------------------------

function ParametricSurface(callback::Function,
                           uRange=range(0.0,1.0,50),vRange=range(0.0,1.0,50),
                           parents::Union{Vector{NodeHandle},Nothing}=nothing,color_data::Union{Nothing,String}=nothing;
                           color="g")::NodeHandle
    c = isnothing(color_data) ? get_color(color) : get_color(color_data)
    return add_node!(callback,ParametricSurface(uRange,vRange,c),parents)
end

macro ParametricSurface(callback::Expr,uRange,vRange,args...)
    (positional_args, kw_args) = _parse_macro_arguments((:color_data,),(:color,), args...)
    callback = _validate_callback_expr(callback, 2)
    return _create_ctor_wrapper(callback, __module__, Juliagebra.ParametricSurface,
                                positional_args,kw_args,
                                (cb, deps) -> (cb, uRange, vRange, deps))
end

export ParametricSurface
export @ParametricSurface