mutable struct PerfLayer
    name::String
    index::UInt
    childs::Union{Nothing,Vector{PerfLayer}}
    PerfLayer(_name::String) = new(_name,0,nothing)
end
mutable struct CPU_times
    start_time::UInt64
    current_index::UInt64
    times::Vector{UInt}
    CPU_times() = new(0,1,zeros(UInt,256))
end
mutable struct GPU_times
    querry_objects::Vector{GLuint}
    head::UInt32
    tail::UInt32
    count::UInt32
    current_index::UInt32
    times::Vector{GLuint64}
    GPU_times() = new(Vector{GLuint}(undef,3),1,1,0,1,zeros(UInt,256))
end
mutable struct PerfBlock
    collect_data::Bool
    cpu::Union{Nothing,CPU_times}
    gpu::Union{Nothing,GPU_times}
    PerfBlock() = new(true,nothing,nothing)
end

const _perf_layers::PerfLayer = PerfLayer("Base")
const _perf_blocks::Vector{PerfBlock} = []
const _perf_gpu_inited::Ref{Bool} = Ref(false)
const _perf_gpu_querry_begin::Ref{Bool} = Ref(false)

const a = 1
const global a = 1

function _get_perf_block_index(layers)::UInt
    perf_block_index::UInt = 0
    current_layer::PerfLayer = _perf_layers
    for (layer_index,layer) in enumerate(layers)
        layer_name = string(layer)
        if current_layer.childs === nothing
            current_layer.childs = [PerfLayer(layer_name)]
            current_layer = current_layer.childs[1]
        else
            index = findfirst(l -> l.name == layer_name, current_layer.childs)
            if index === nothing
                current_layer.childs = [PerfLayer(layer_name)]
                current_layer = last(current_layer.childs)
            else
                current_layer = current_layer.childs[index]
            end
        end

        if layer_index == length(layers)
            if current_layer.index == 0
                push!(_perf_blocks,PerfBlock())
                current_layer.index = length(_perf_blocks)
            end
            perf_block_index = current_layer.index
        end
    end
    return perf_block_index
end

function _time_cpu_begin(index::UInt)
    if !_perf_blocks[index].collect_data return end
    cpu::CPU_times = _perf_blocks[index].cpu
    if cpu.start_time != 0
        @log "Missing time_end_cpu call" ERR
    end
    cpu.start_time = time_ns()
end
function _time_cpu_end(index::UInt)
    if !_perf_blocks[index].collect_data return end
    cpu::CPU_times = _perf_blocks[index].cpu
    if cpu.start_time == 0
        @log "Missing time_begin_cpu call" ERR
    end
    time = time_ns()
    cpu.times[cpu.current_index] = time - cpu.start_time
    cpu.start_time = 0
    cpu.current_index = mod1(cpu.current_index + 1,length(cpu.times))
end

function _gpu_collect_at_tail!(gpu::GPU_times)
    time_ns = GLuint64[0]
    glGetQueryObjectui64v(gpu.querry_objects[gpu.tail], GL_QUERY_RESULT, time_ns)

    gpu.times[gpu.current_index] = time_ns[]
    gpu.current_index = mod1(gpu.current_index+1,length(gpu.times))

    gpu.tail = mod1(gpu.tail+1, length(gpu.querry_objects))
    gpu.count -= 1
end

function _gpu_noblock_get_times(gpu::GPU_times)
    while gpu.count > 0
        available = GLint[0]
        glGetQueryObjectiv(gpu.querry_objects[gpu.tail], GL_QUERY_RESULT_AVAILABLE, available)
        if available[1] == GL_TRUE _gpu_collect_at_tail!(gpu)
        else break end
    end
end

function _time_gpu_begin(index::UInt)
    global _perf_gpu_querry_begin
    if _perf_gpu_querry_begin[]
        @log "GPU queries cant overlap" ERR
        return
    end
    _perf_gpu_querry_begin[] = true
    
    if !_perf_blocks[index].collect_data || !_perf_gpu_inited[] return end
    gpu::GPU_times = _perf_blocks[index].gpu
    _gpu_noblock_get_times(gpu)

    if gpu.count == length(gpu.querry_objects)
        _gpu_collect_at_tail!(gpu)
    end

    glBeginQuery(GL_TIME_ELAPSED, gpu.querry_objects[gpu.head])
    gpu.head = mod1(gpu.head+1,length(gpu.querry_objects))
    gpu.count += 1
end
function _time_gpu_end(index::UInt)
    global _perf_gpu_querry_begin
    if !_perf_gpu_querry_begin[]
        @log "GPU queries cant overlap" ERR
        return
    end
    _perf_gpu_querry_begin[] = false
    if !_perf_blocks[index].collect_data || !_perf_gpu_inited[] return end
    glEndQuery(GL_TIME_ELAPSED)
end

macro time_cpu_begin(layers...)
    index = _get_perf_block_index(layers)
    block::PerfBlock = _perf_blocks[index]
    if block.cpu === nothing
        block.cpu = CPU_times()
    end
    return quote
        _time_cpu_begin($index)
    end
end
macro time_cpu_end(layers...)
    index = _get_perf_block_index(layers)
    block::PerfBlock = _perf_blocks[index]
    if block.cpu === nothing
        block.cpu = CPU_times()
    end
    return quote
        _time_cpu_end($index)
    end
end
macro time_gpu_begin(layers...)
    index = _get_perf_block_index(layers)
    block::PerfBlock = _perf_blocks[index]
    if block.gpu === nothing
        block.gpu = GPU_times()
    end
    return quote
        _time_gpu_begin($index)
    end
end
macro time_gpu_end(layers...)
    index = _get_perf_block_index(layers)
    block::PerfBlock = _perf_blocks[index]
    if block.gpu === nothing
        block.gpu = GPU_times()
    end
    return quote
        _time_gpu_end($index)
    end
end

function perf_init_gpu()
    for perfblock::PerfBlock in _perf_blocks
        if perfblock.gpu !== nothing
            glGenQueries(length(perfblock.gpu.querry_objects), perfblock.gpu.querry_objects)
        end
    end
    global _perf_gpu_inited[] = true
end
function perf_get_results()
    for perfblock::PerfBlock in _perf_blocks
        if perfblock.gpu !== nothing
            _gpu_noblock_get_times(perfblock.gpu)
        end
    end
end
function perf_set_all_collect_data(collect_data::Bool)
    for perfblock::PerfBlock in _perf_blocks
        perfblock.collect_data = collect_data
    end
end

function get_cpu_times(layer::PerfLayer)::Union{Nothing, Base.Iterators.Filter}
    if layer.index == 0 return nothing end
    cpu = _perf_blocks[layer.index].cpu
    return cpu === nothing ? nothing : Iterators.filter(x -> x != 0, cpu.times)
end
function get_gpu_times(layer::PerfLayer)::Union{Nothing, Base.Iterators.Filter}
    if layer.index == 0 return nothing end
    gpu = _perf_blocks[layer.index].gpu
    return gpu === nothing ? nothing : Iterators.filter(x -> x != 0, gpu.times)
end
get_collect_data(layer::PerfLayer) = _perf_blocks[layer.index].collect_data
set_collect_data(layer::PerfLayer,collect_data::Bool) = _perf_blocks[layer.index].collect_data = collect_data