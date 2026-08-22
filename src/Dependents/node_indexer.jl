const _indexer_cache = Dict{Tuple{UInt32,Int},NodeHandle}()
on_window_clear(() -> empty!(_indexer_cache))

struct NodeIndexer
    ref::Base.RefArray{Any, Vector{Any}, Nothing}
    index::Int
end

convert_callback_entry(indexer::NodeIndexer)::Any = convert_callback_entry(indexer.ref[][indexer.index])
convert_callback_result(indexer::NodeIndexer, ::Nothing)::NodeIndexer = indexer
Base.show(io::IO, indexer::NodeIndexer) = Base.show(io,indexer.ref[][indexer.index])

_empty_indexer_func(::Any) = nothing # Hack for now
function Base.getindex(handle::NodeHandle,index::Int)::NodeHandle
    key = (handle.value,index)
    if haskey(_indexer_cache, key)
        return _indexer_cache[key]
    end
    global implicitApp
    app::App = implicitApp::App
    new_indexer = add_node!(_empty_indexer_func,NodeIndexer(Ref(app.graph.elements,handle.value),index);parents=[handle])
    _indexer_cache[key] = new_indexer
    return new_indexer
end