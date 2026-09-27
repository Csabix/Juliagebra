mutable struct ParametricSurface{Range<:AbstractRange}
    vertexes::FlatMatrixManager{Vec3F}
    indexes::Vector{UInt32}
    uvValues::FlatMatrix{Vec3D}
    # uvNormals::FlatMatrix{Vec3D}
    uRange::Range
    vRange::Range
    param_tess_data::ParamTessData

    function ParametricSurface(uRange::Range, vRange::Range, param_tess_data::ParamTessData) where {Range<:AbstractRange}
        vertexes = FlatMatrixManager{Vec3F}()
        indexes = Vector{UInt32}()
        uvValues = FlatMatrix{Vec3D}(length(uRange), length(vRange))
        # uvNormals = FlatMatrix{Vec3D}(length(uRange), length(vRange))
        new{Range}(vertexes, indexes, uvValues, #= uvNormals, =# uRange, vRange, param_tess_data)
    end
end

struct ParametricSurfaceDrawData
    handle::UInt32
    color::UInt32
end

const GPU_TESS_SURFACE_UV_RANGE = :JG_TESS_UV_RANGE
const GPU_TESS_SURFACE_GRID_WIDTH = :JG_TESS_GRID_WIDTH
const GPU_TESS_SURFACE_NODE_UNIFORMS = Dict{Symbol,DataType}(
    GPU_TESS_SURFACE_UV_RANGE => Vec4F,
    GPU_TESS_SURFACE_GRID_WIDTH => Int32
)

convert_result!(ps::ParametricSurface,result,u,v) = (ps.uvValues[u,v] = Vec3D(result);ps)
convert_result!(ps::ParametricSurface,result::Tuple,u,v) = (ps.uvValues[u,v] = Vec3D(result...);ps)
convert_result!(ps::ParametricSurface,result::Vec3F,u,v) = (ps.uvValues[u,v] = Vec3D(result);ps)
convert_result!(ps::ParametricSurface,result::Vec3D,u,v) = (ps.uvValues[u,v] = result;ps)
convert_result!(ps::ParametricSurface,::Nothing,u,v) = (ps.uvValues[u,v] = Vec3DNan;ps)

# function setNormal!(element::ParametricSurface, u::Int, v::Int, w::Int, h::Int)
#     vals = element.uvValues
# 
#     right = vals[min(u + 1, w), v]
#     left  = vals[max(u - 1, 1), v]
#     down  = vals[u, min(v + 1, h)]
#     up    = vals[u, max(v - 1, 1)]
# 
#     uVec = right - left
#     vVec = down - up
#     element.uvNormals[u, v] = normalize(cross(uVec, vVec))
# end

eval_geometry_node(element::ParametricSurface, node::GeometryPlotNode, elements::Vector{Any}) =
    handle_param_tess!(element.param_tess_data, element, node, elements; pos_buffer_read=true, pos_buffer_write=false)

function eval_node(element::ParametricSurface, callback::Function, arguments::Vector{Any})::Any
    for (v, vf) in enumerate(element.vRange), (u, uf) in enumerate(element.uRange)
        res = callback(uf, vf, arguments...)
        convert_result!(element, res, u, v)
    end

    # w = width(element.uvValues)
    # h = height(element.uvValues)
    # for v in 1:h, u in 1:w
    #     setNormal!(element, u, v, w, h)
    # end

    return element
end

function update_node_uniforms!(uniform_values::Dict{Symbol,Any}, element::ParametricSurface)
    uniform_values[GPU_TESS_SURFACE_UV_RANGE] = Vec4F(first(element.uRange), step(element.uRange), first(element.vRange), step(element.vRange))
    uniform_values[GPU_TESS_SURFACE_GRID_WIDTH] = GLint(width(element.uvValues))
end

function convert_gpu_result(element::ParametricSurface,pos_buffer::MappedBuffer{Vec4})::Tuple{Bool,Any}
    grid_width = width(element.uvValues)
    @inbounds for v in eachindex(element.vRange), u in eachindex(element.uRange)
        convert_result!(element, pos_buffer._mapped[(v-1)*grid_width+u].xyz, u, v)
    end

    return (true, element)
end

function render_node(ps::ParametricSurface, pdata::ParametricSurfaceDrawData, renderers::Dict{DataType,Renderer}, id::UInt32)::ParametricSurfaceDrawData
    @time_cpu_begin ParamTess Render Surface
    triangle_renderer::TriangleRenderer = renderers[TriangleRenderer]
    if pdata.handle == 0
        width = length(ps.uRange)
        height = length(ps.vRange)
        initMatrix(ps.vertexes, width, height, Vec3FNan)
        triangulateInto!(ps.indexes, ps.vertexes, layers(ps.vertexes))
        copy!(ps.uvValues, ps.vertexes, layers(ps.vertexes))
        triangles = get_triangulated(data(ps.vertexes, layers(ps.vertexes)), ps.vertexes, layers(ps.vertexes))
        handle = add!(triangle_renderer, triangles, mat4(1.0f0), pdata.color, false, id)
        @time_cpu_end ParamTess Render Surface
        return ParametricSurfaceDrawData(handle, pdata.color)
    else
        @time_cpu_begin ParamTess Render Surface Triangulate
        copy!(ps.uvValues, ps.vertexes, layers(ps.vertexes))
        triangles = get_triangulated(data(ps.vertexes, layers(ps.vertexes)), ps.vertexes, layers(ps.vertexes))
        @time_cpu_end ParamTess Render Surface Triangulate
        @time_cpu_begin ParamTess Render Surface UpdateCoords
        update_coords!(triangle_renderer, pdata.handle, triangles)
        @time_cpu_end ParamTess Render Surface UpdateCoords
        @time_cpu_end ParamTess Render Surface
        return pdata
    end
end

# ? For Intersectable ParametricSurfaces.
struct PTrianglesOfSurface <: PrimitivesOf{PTriangle}
    _surfaceTriangleIterator::TrianglesOf
end
PrimitivesOf(self::ParametricSurface) = return PTrianglesOfSurface(TrianglesOf(self.uvValues))
Base.length(self::PTrianglesOfSurface) = return length(self._surfaceTriangleIterator)
Base.getindex(self::PTrianglesOfSurface, index::UInt)::PTriangle = return self._surfaceTriangleIterator[index]
Base.iterate(self::PTrianglesOfSurface, state = (1,1,1)) = return iterate(self._surfaceTriangleIterator,state)   

function wrap_surface_callback(callback_ast::Expr)::Union{Expr,Nothing}
    dbg::Bool = (GPU_TESS_DEBUG_ARG in ARGS)

    if !_is_normalized_callback(callback_ast)
        dbg && @log "Cannot transpile callback AST that has not been normalized"
        return nothing
    end

    if length(callback_ast.args[1].args) < 2
        dbg && @log "Cannot transpile callback with zero or one argument as a surface"
        return nothing
    end

    result = deepcopy(callback_ast)

    u_varname = result.args[1].args[1]
    v_varname = result.args[1].args[2]
    deleteat!(result.args[1].args, 1:2)

    pushfirst!(result.args[2].args,
        :($u_varname = $GPU_TESS_SURFACE_UV_RANGE.x + (Int32(JG_TESS_ID) % $GPU_TESS_SURFACE_GRID_WIDTH) * $GPU_TESS_SURFACE_UV_RANGE.y),
        :($v_varname = $GPU_TESS_SURFACE_UV_RANGE.z + div(Int32(JG_TESS_ID), $GPU_TESS_SURFACE_GRID_WIDTH) * $GPU_TESS_SURFACE_UV_RANGE.w)
    )

    return result
end

edit_node_overload(::ParametricSurface)::Bool = true
function edit_node(ps::ParametricSurface,data::ParametricSurfaceDrawData,renderers::Dict{DataType,Renderer},handle::NodeHandle)::Tuple{Any,Any,Int}
    result = EDIT_NODE_NONE

    CImGui.Text("Tessellation Mode: $(ps.param_tess_data.current_mode)")

    CImGui.SameLine()
    if CImGui.Button("-> CPU")
        ps.param_tess_data.next_mode = ParamTessMode.CPU
        result |= EDIT_NODE_INVALIDATE
    end
    
    CImGui.SameLine()
    if CImGui.Button("-> GPU")
        ps.param_tess_data.next_mode = ParamTessMode.GPU
        result |= EDIT_NODE_INVALIDATE
    end
    
    return ps, data, result
end

# ? ---------------------------------
# ! ParametricSurfaceRenderer
# ? ---------------------------------

function ParametricSurface(callback::Function,
                           uRange=range(0.0,1.0,50), vRange=range(0.0,1.0,50),
                           parents::Union{Vector{NodeHandle},Nothing}=nothing, color_data::Union{Nothing,String}=nothing;
                           color="g",callback_ast::Union{Expr,Nothing}=nothing,argument_bindings::Union{Dict{Symbol,NodeHandle},Nothing}=nothing,
                           enable_gpu_tessellation::Bool=false)::NodeHandle
    c = isnothing(color_data) ? get_color(color) : get_color(color_data)

    if !enable_gpu_tessellation
        callback_ast = nothing
        argument_bindings = nothing
    elseif callback_ast !== nothing
        callback_ast = wrap_surface_callback(callback_ast)
    end
    n = length(uRange) * length(vRange)
    param_tess_data = (callback_ast !== nothing && argument_bindings !== nothing) ?
        ParamTessData(callback_ast, argument_bindings, GPU_TESS_SURFACE_NODE_UNIFORMS, n) :
        ParamTessData(n)

    return add_node!(callback, ParametricSurface(uRange, vRange, param_tess_data); draw_data=ParametricSurfaceDrawData(UInt32(0), c), parents=parents,
                     use_main_thread=(param_tess_data.transpilation_src !== nothing))
end

macro ParametricSurface(callback::Expr,uRange,vRange,args...)
    (positional_args, kw_args) = _parse_macro_arguments((:color_data,),(:color, :enable_gpu_tessellation), args...)
    callback = _validate_callback_expr(callback, 2)
    return _create_ctor_wrapper(callback, __module__, Juliagebra.ParametricSurface,
                                positional_args,kw_args,
                                (cb, deps) -> (cb, uRange, vRange, deps), true)
end

export ParametricSurface
export @ParametricSurface