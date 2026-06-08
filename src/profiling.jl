@kwdef struct Profiler
    start_query_objects::Vector{GLuint} = GLuint[]
    end_query_objects::Vector{GLuint} = GLuint[]
    gpu_times::Vector{GLuint64} = GLuint64[]
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
    fill!(profiler.gpu_times, GLuint64(0))
    return nothing
end

function add_gpu_stopwatch(profiler::Profiler)::UInt32
    push!(profiler.start_query_objects, GLuint(0))
    push!(profiler.end_query_objects, GLuint(0))
    push!(profiler.gpu_times, GLuint64(0))
    return UInt32(length(profiler.gpu_times))
end

function begin_gpu(profiler::Profiler, handle::UInt32)::Nothing
    @inbounds glQueryCounter(profiler.start_query_objects[handle], GL_TIMESTAMP)
    return nothing
end

function end_gpu(profiler::Profiler, handle::UInt32)::Nothing
    @inbounds glQueryCounter(profiler.end_query_objects[handle], GL_TIMESTAMP)
    return nothing
end

function frame_end(profiler::Profiler)::Nothing
    start_ns = Ref{GLuint64}()
    end_ns = Ref{GLuint64}()
    for i in eachindex(profiler.gpu_times)
        @inbounds glGetQueryObjectui64v(profiler.start_query_objects[i], GL_QUERY_RESULT, start_ns)
        @inbounds glGetQueryObjectui64v(profiler.end_query_objects[i], GL_QUERY_RESULT, end_ns)
        @inbounds profiler.gpu_times[i] = end_ns[] - start_ns[]
    end
    return nothing
end