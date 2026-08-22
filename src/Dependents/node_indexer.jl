const _indexer_cache = Dict{Tuple{UInt32,Int},NodeHandle}()
on_window_clear(() -> empty!(_indexer_cache))

struct NodeIndexer
    ref::Base.RefArray{Any, Vector{Any}, Nothing}
    index::Int
end

convert_callback_entry(indexer::NodeIndexer)::Any = convert_callback_entry(indexer.ref[][indexer.index])
convert_callback_result(indexer::NodeIndexer, ::Nothing)::NodeIndexer = indexer
function Base.show(io::IO, indexer::NodeIndexer)
    print(io, "NodeIndexer(index=$(indexer.index),")
    if checkbounds(Bool, indexer.ref[], indexer.index)
        show(io, indexer.ref[][indexer.index])
    else
        print(io, "INVALID INDEX")
    end
    print(io, ")")
end

_empty_indexer_func(::Any) = nothing # Hack for now
function Base.getindex(handle::NodeHandle,index::Int)::NodeHandle
    if implicitApp === nothing || !checkbounds(Bool, implicitApp.graph.elements, handle.value)
        return NodeHandle(0)
    end
    key = (handle.value,index)
    if haskey(_indexer_cache, key)
        return _indexer_cache[key]
    end
    new_indexer = add_node!(_empty_indexer_func,NodeIndexer(Ref(implicitApp.graph.elements,handle.value),index);parents=[handle])
    _indexer_cache[key] = new_indexer
    return new_indexer
end