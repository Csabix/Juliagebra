struct NodeHandle
    value::UInt32
end

Base.to_index(handle::NodeHandle)::Int = Int(handle.value)