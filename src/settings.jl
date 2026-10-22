using Scratch
import TOML

struct GlobalSettings
    scratch_path::String
    toml_file::String
    settings::Dict{String, Any}
    settings_hints::Dict{String, PropertyHint}
end

global_settings::Union{GlobalSettings, Nothing} = nothing

modified_notification::Dict{String, Set{Function}} = Dict()

function default_settings()::Dict{String,Any}
    return Dict{String,Any}(
        "Graphics" => Dict{String, Any}(
            "Display" => Dict{String, Any}(
                "Enable VSync" => true,
                "Max FPS" => 60,
                "Background color" => UInt32(0xFFFFFFFF)
            ),
            "Renderers" => Dict{String, Any}(

            )
        ),
        "Evaluator" => Dict{String, Any}(

        ),
        "Controls" => Dict{String, Any}(
            "Invert camera" => Dict{String, Any}(
                "Panning" => Dict{String, Any}(
                    "X" => false,
                    "Y" => false
                ),
                "Rotation" => Dict{String, Any}(
                    "X" => false,
                    "Y" => false
                )
            ),
            "Mouse sensitivity" => Dict{String, Any}(
                    "X" => 1.0,
                    "Y" => 1.0
            ),
            "Keybinds" => Dict{String, Any}(
                 
            )
        ),
        "Geometry" => Dict{String, Any}(

        )
    )
end

function settings_hints()::Dict{String, PropertyHint}
    return Dict{String, PropertyHint}(
        "Graphics/Display/Background color" => PropertyHintColor(false)
    )
end

function get_Setting_hint(path::String)::Union{PropertyHint, Nothing}
    @assert global_settings !== nothing "Settings are uninitialized"
    return get(global_settings.settings_hints, path, nothing)
end

function init_settings(scratch_path::String = "global_settings", toml_file::String="settings.toml", default=default_settings(), edit_hints=settings_hints())
    path = @get_scratch!(scratch_path) *"/"*toml_file
    # if file exists -> read file
    if isfile(path)
        d = TOML.parsefile(path)
        global global_settings = GlobalSettings(scratch_path, toml_file, d, edit_hints)
    # else -> generate dict, write file
    else
        global global_settings = GlobalSettings(scratch_path, toml_file, default,edit_hints)
        save_settings()
    end
    println(path)
    println(global_settings)
end

function get_global_setting(path::String)::Any
    @assert global_settings !== nothing "Settings are uninitialized"
    names = split(path, "/")
    if length(names) < 1
        throw(ArgumentError("Empty path"))
    end
    current = global_settings.settings
    for n in names
        if !haskey(current, n)
            throw(ArgumentError("Setting not not found: "*path))
        end
        current = current[n]
    end
    return current
end

function set_global_setting(path::String, value::Any)
    @assert global_settings !== nothing "Settings are uninitialized"
    # assert path exists
    # get current value
    old = get_global_setting(path)
    # assert types match
    value = oftype(old, value)
    # set new value
    names = split(path, "/")
    current = global_settings.settings
    for n in 1:length(names)-1
        current = current[names[n]]
    end
    current[names[end]] = value
    # serialize
    save_settings()
    # callback
    if haskey(modified_notification, path)
        for f::Function in modified_notification[path]
            f()
        end
    end
end

function save_settings()
    @assert global_settings !== nothing "Settings are uninitialized"
    path = @get_scratch!(global_settings.scratch_path)
    path = touch(path*"/"*global_settings.toml_file)
    file = open(path, "w")
    TOML.print(file, global_settings.settings)
    close(file)
end

function on_setting_changed(setting::String, func::Function)
    func_set = get(modified_notification, setting, Set{Function}())
    modified_notification[setting] = func_set
    push!(func_set, func)
end
