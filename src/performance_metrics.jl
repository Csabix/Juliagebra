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
    # TODO
    times::Vector{UInt}
end
mutable struct PerfBlock
    collect_data::Bool
    cpu::Union{Nothing,CPU_times}
    gpu::Union{Nothing,GPU_times}
    PerfBlock() = new(true,nothing,nothing)
end

const global _perf_layers::PerfLayer = PerfLayer("Base")
const global _perf_blocks::Vector{PerfBlock} = []

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