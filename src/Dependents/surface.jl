mutable struct ParametricSurface{Range<:AbstractRange}
    values::Matrix{Vec3D}
    uRange::Range
    vRange::Range
    param_tess_data::ParamTessData

    function ParametricSurface(uRange::Range, vRange::Range, param_tess_data::ParamTessData) where {Range<:AbstractRange}
        new{Range}(Matrix{Vec3D}(undef, length(uRange), length(vRange)), uRange, vRange, param_tess_data)
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

Base.@propagate_inbounds convert_result!(ps::ParametricSurface,result,u,v) = (ps.values[u,v] = Vec3D(result);ps)
Base.@propagate_inbounds convert_result!(ps::ParametricSurface,result::Tuple,u,v) = (ps.values[u,v] = Vec3D(result...);ps)
Base.@propagate_inbounds convert_result!(ps::ParametricSurface,result::Vec3F,u,v) = (ps.values[u,v] = Vec3D(result);ps)
Base.@propagate_inbounds convert_result!(ps::ParametricSurface,result::Vec3D,u,v) = (ps.values[u,v] = result;ps)
Base.@propagate_inbounds convert_result!(ps::ParametricSurface,::Nothing,u,v) = (ps.values[u,v] = Vec3DNan;ps)

eval_geometry_node(ps::ParametricSurface, node::GeometryPlotNode, elements::Vector{Any}) = handle_param_tess!(ps.param_tess_data, ps, node, elements)

function eval_node(ps::ParametricSurface, callback::Function, arguments::Vector{Any})::Any
    _fill_surface!(ps, callback, arguments...)
    return ps
end

function update_node_uniforms!(uniform_values::Dict{Symbol,Any}, ps::ParametricSurface)
    uniform_values[GPU_TESS_SURFACE_UV_RANGE] = Vec4F(first(ps.uRange), step(ps.uRange), first(ps.vRange), step(ps.vRange))
    uniform_values[GPU_TESS_SURFACE_GRID_WIDTH] = GLint(length(ps.uRange))
end

get_param_tess_data(ps::ParametricSurface)::ParamTessData = ps.param_tess_data

function convert_gpu_result!(ps::ParametricSurface,tess_buffer::MappedBuffer{Vec4})
    grid_width = length(ps.uRange)
    @inbounds for v in eachindex(ps.vRange), u in eachindex(ps.uRange)
        convert_result!(ps, tess_buffer._mapped[(v-1)*grid_width+u].xyz, u, v)
    end
end

function _fill_surface!(ps::ParametricSurface, callback::F, args::Vararg{Any,N}) where {F,N}
    for (v, vf) in enumerate(ps.vRange), (u, uf) in enumerate(ps.uRange)
        @inbounds convert_result!(ps, callback(uf, vf, args...), u, v)
    end
    return ps
end

function render_node(ps::ParametricSurface, pdata::ParametricSurfaceDrawData, renderers::Dict{DataType,Renderer}, id::UInt32)::ParametricSurfaceDrawData
    triangle_renderer::TriangleRenderer = renderers[TriangleRenderer]
    gpu = ps.param_tess_data.current_mode === ParamTessMode.GPU
    if pdata.handle == 0
        handle = if gpu
            @assert ps.param_tess_data.gpu_data !== nothing
            add!(triangle_renderer, ps.param_tess_data.gpu_data.tess_buffer, length(ps.uRange), mat4(1.0f0), pdata.color, id)
        else
            add!(triangle_renderer, get_triangulated(ps.values), mat4(1.0f0), pdata.color, false, id)
        end
        return ParametricSurfaceDrawData(handle, pdata.color)
    else
        if gpu
            update_coords!(triangle_renderer, pdata.handle, ps.param_tess_data.gpu_data.tess_buffer, length(ps.uRange))
        else
            update_coords!(triangle_renderer, pdata.handle, get_triangulated(ps.values))
        end
        return pdata
    end
end

PrimitivesOf(self::ParametricSurface) = PTrianglesOfSurface(self.values)

function wrap_surface_callback(callback_ast::Expr)::Union{Expr,Nothing}
    if !_is_normalized_callback(callback_ast)
        DBG_TESS && @log "Cannot transpile callback AST that has not been normalized"
        return nothing
    end

    if length(callback_ast.args[1].args) < 2
        DBG_TESS && @log "Cannot transpile callback with zero or one argument as a surface"
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
edit_node_name(::ParametricSurface)::String = "ParametricSurface" # drop range type params
edit_node(ps::ParametricSurface,data::ParametricSurfaceDrawData,::Dict{DataType,Renderer},handle::NodeHandle)::Tuple{Any,Any,Int} = ps, data, edit_param_tess_data!(ps.param_tess_data,handle)

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