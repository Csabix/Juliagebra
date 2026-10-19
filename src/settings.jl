using Scratch
using TOML

struct GlobalSettings
    scratch_path::String
    toml_file::String
    settings::Dict{String, Any}
end


global_settings::Union{Nothing, GlobalSettings} = nothing

function init_settings()
    println(global_settings)
end

# x/y/z:v
function get_global_setting(path::String)::Any
end
