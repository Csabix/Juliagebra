const _alpha = 0.1
@kwdef struct Profiler
    start_query_objects::Vector{GLuint} = GLuint[]
    end_query_objects::Vector{GLuint} = GLuint[]
    gpu_times::Vector{Float64} = Float64[]
    called_this_frame_gpu::Vector{Bool} = Bool[]

    cpu_times::Vector{Float64} = Float64[]
    cpu_times_begin::Vector{UInt64} = UInt64[]
    cpu_times_end::Vector{UInt64} = UInt64[]
    called_this_frame_cpu::Vector{Bool} = Bool[]
end

function init!(profiler::Profiler)::Nothing
    len = length(profiler.start_query_objects)
    if len > 0
        glGenQueries(len, profiler.start_query_objects)
        glGenQueries(len, profiler.end_query_objects)
    end
    return nothing
end

function destroy!(profiler::Profiler)::Nothing
    len = length(profiler.start_query_objects)
    if len > 0
        glDeleteQueries(len, profiler.start_query_objects)
        glDeleteQueries(len, profiler.end_query_objects)
    end
    empty!(profiler.start_query_objects)
    empty!(profiler.end_query_objects)
    fill!(profiler.gpu_times, 0.0)
    return nothing
end

function add_gpu_stopwatch(profiler::Profiler)::UInt32
    push!(profiler.start_query_objects, GLuint(0))
    push!(profiler.end_query_objects, GLuint(0))
    push!(profiler.gpu_times, 0.0)
    push!(profiler.called_this_frame_gpu, false)
    return UInt32(length(profiler.gpu_times))
end

function add_cpu_stopwatch(profiler::Profiler)::UInt32
    push!(profiler.cpu_times, 0.0)
    push!(profiler.cpu_times_begin, 0)
    push!(profiler.cpu_times_end, 0)
    push!(profiler.called_this_frame_cpu, false)
    return UInt32(length(profiler.cpu_times))
end

function begin_gpu(profiler::Profiler, handle::UInt32)::Nothing
    @inbounds glQueryCounter(profiler.start_query_objects[handle], GL_TIMESTAMP)
    @inbounds profiler.called_this_frame_gpu[handle] = true
    return nothing
end

function end_gpu(profiler::Profiler, handle::UInt32)::Nothing
    @inbounds glQueryCounter(profiler.end_query_objects[handle], GL_TIMESTAMP)
    return nothing
end

function begin_cpu(profiler::Profiler, handle::UInt32)::Nothing
    @inbounds profiler.cpu_times_begin[handle] = time_ns()
    @inbounds profiler.called_this_frame_cpu[handle] = true
    return nothing
end

function end_cpu(profiler::Profiler, handle::UInt32)::Nothing
    @inbounds profiler.cpu_times_end[handle] = time_ns()
    return nothing
end

function frame_end(profiler::Profiler)::Nothing
    start_ns = Ref{GLuint64}()
    end_ns = Ref{GLuint64}()
    for i in eachindex(profiler.gpu_times)
        if @inbounds profiler.called_this_frame_gpu[i]
            @inbounds glGetQueryObjectui64v(profiler.start_query_objects[i], GL_QUERY_RESULT, start_ns)
            @inbounds glGetQueryObjectui64v(profiler.end_query_objects[i], GL_QUERY_RESULT, end_ns)
            new_time = (end_ns[] - start_ns[]) / 1000000.0
            old_time = @inbounds profiler.gpu_times[i]
            @inbounds profiler.gpu_times[i] = (1.0 - _alpha) * old_time + _alpha * new_time
        else
            @inbounds profiler.gpu_times[i] = 0.0
        end
        @inbounds profiler.called_this_frame_gpu[i] = false
    end

    for i in eachindex(profiler.cpu_times)
        if @inbounds profiler.called_this_frame_cpu[i]
            new_time = (profiler.cpu_times_end[i] - profiler.cpu_times_begin[i]) / 1000000.0
            old_time = @inbounds profiler.cpu_times[i]
            @inbounds profiler.cpu_times[i] = (1.0 - _alpha) * old_time + _alpha * new_time
        else
            @inbounds profiler.cpu_times[i] = 0.0
        end
        @inbounds profiler.called_this_frame_cpu[i] = false
    end
    return nothing
end