const _ASSET_WATCHER_CHECK_EVERY_S::Float64 = 3.0

function _watcher_get_extenstion(full_path::String)::SubString{String}
    dot_index = findlast('.', full_path)
    if isnothing(dot_index) || dot_index == lastindex(full_path)
        return SubString(full_path, 1, 0)
    end
    return SubString(full_path, nextind(full_path, dot_index))
end

@kwdef mutable struct AssetWatcher
    accum_s::Float64 = 0.0
    iterator::Union{Tuple{Pair{String,Float64},Int64},Nothing} = nothing
    watched_folders::Set{String} = Set{String}()
    watched_files::Dict{String,Float64} = Dict{String,Float64}()
    deleted_files::Vector{String} = Vector{String}()
    file_added_callback::Dict{String,Function} = Dict{String,Function}()
    file_changed_callback::Dict{String,Function} = Dict{String,Function}()
    file_deleted_callback::Dict{String,Function} = Dict{String,Function}()
end

function watch_folder!(watcher::AssetWatcher, folder::String, recursive::Bool=true)::Nothing
    folder = normpath(folder)
    push!(watcher.watched_folders, folder)
    if recursive
        for (root, dirs, _) in walkdir(folder)
            for dir in dirs
                push!(watcher.watched_folders, joinpath(root, dir))
            end
        end
    end
    return nothing
end

function set_file_added_callback(watcher::AssetWatcher, extension::String, callback::Function)::Nothing
    watcher.file_added_callback[extension] = callback
    return nothing
end
function set_file_added_callback(watcher::AssetWatcher, extensions, callback::Function)::Nothing
    for extension in extensions
        watcher.file_added_callback[extension] = callback
    end
    return nothing
end

function set_file_changed_callback(watcher::AssetWatcher, extension::String, callback::Function)::Nothing
    watcher.file_changed_callback[extension] = callback
    return nothing
end
function set_file_changed_callback(watcher::AssetWatcher, extensions, callback::Function)::Nothing
    for extension in extensions
        watcher.file_changed_callback[extension] = callback
    end
    return nothing
end

function set_file_deleted_callback(watcher::AssetWatcher, extension::String, callback::Function)::Nothing
    watcher.file_deleted_callback[extension] = callback
    return nothing
end
function set_file_deleted_callback(watcher::AssetWatcher, extensions, callback::Function)::Nothing
    for extension in extensions
        watcher.file_deleted_callback[extension] = callback
    end
    return nothing
end

function _update_watched_files!(watcher::AssetWatcher)::Nothing
    watcher.accum_s = 0.0
    for file in watcher.deleted_files
        delete!(watcher.watched_files, file)
    end
    empty!(watcher.deleted_files)

    for folder in watcher.watched_folders
        for file in readdir(folder; join=true, sort=false)
            if !haskey(watcher.watched_files, file)
                ext = _watcher_get_extenstion(file)
                if haskey(watcher.file_added_callback, ext)
                    watcher.file_added_callback[ext](file)
                end
                watcher.watched_files[file] = mtime(file)
            end
        end
    end

    watcher.iterator = iterate(watcher.watched_files)
    return nothing
end

function update!(watcher::AssetWatcher, delta_time::Float64)::Nothing
    length(watcher.file_added_callback) == 0 &&
    length(watcher.file_changed_callback) == 0 &&
    length(watcher.file_deleted_callback) == 0 &&
    return nothing

    watcher.accum_s += delta_time
    num_files = max(1, length(watcher.watched_files))
    time_per_file = _ASSET_WATCHER_CHECK_EVERY_S / Float64(num_files)

    if isnothing(watcher.iterator) # No watched file
        if watcher.accum_s > _ASSET_WATCHER_CHECK_EVERY_S
            _update_watched_files!(watcher)
        end
        return nothing
    end
    while watcher.accum_s >= time_per_file
        if isnothing(watcher.iterator)
            _update_watched_files!(watcher)
            break
        end
        (file, last_time), state = watcher.iterator
        watcher.iterator = iterate(watcher.watched_files, state)
        watcher.accum_s -= time_per_file
        ext = _watcher_get_extenstion(file)
        if isfile(file)
            curr_time = mtime(file)
            if curr_time != last_time # File changed
                watcher.watched_files[file] = curr_time
                if haskey(watcher.file_changed_callback, ext)
                    watcher.file_changed_callback[ext](file)
                end
            end
        else # Deleted file
            if haskey(watcher.file_deleted_callback, ext)
                watcher.file_deleted_callback[ext](file)
            end
            push!(watcher.deleted_files, file)
        end
    end
    return nothing
end