using Scratch
import TOML

struct GlobalSettings
    scratch_path::String
    toml_file::String
    settings::Dict{String, Any}
    settings_hints::Dict{String, Any}
    modified_notification::Dict{String, Set{Function}}
    modified_bindings::Dict{Pair{Function, String}, Vector{Vector{Any}}}
end

global_settings::Union{GlobalSettings, Nothing} = nothing

function default_settings()::Dict{String,Any}
    return Dict{String,Any}(
        "Graphics" => Dict{String, Any}(
            "Display" => Dict{String, Any}(
                "Framerate" => Dict{String, Any}(
                    "Enable VSync" => 2,
                    "Limit Framerate" => false,
                    "Max FPS" => 60
                ),
                
                "Background color" => UInt32(0xFFFFFFFF),
                "Infinite AABB" => Dict{String, Any}(
                    "Minimum" => Vec3D(-10.0,-10.0,-10.0),
                    "Maximum" => Vec3D(10.0,10.0,10.0)
                ),
                "Gizmo" => Dict{String, Any}(
                    "Length" => 1.0,
                    "Thickness" => 1.0
                )
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
            
        ),
        "Geometry" => Dict{String, Any}(

        )
    )
end

function settings_hints()::Dict{String, Any}
    return Dict{String,Any}(
        "Graphics" => Dict{String, Any}(
            "Display" => Dict{String, Any}(
                "Framerate" =>Dict{String, Any}(
                    "Enable VSync" => PropertyHintEnum(["Adaptive (-1)", "Off (0)", "On (1)"]),
                    "Max FPS" => PropertyHintSlider(10.0, 144.0),
                    "Limit Framerate"=> nothing
                ),
                
                "Background color" => PropertyHintColor(false),
                "Gizmo" => Dict{String, Any}(
                    "Length" => PropertyHintSlider(0.0, 10.0),
                    "Thickness" => PropertyHintSlider(0.0, 10.0)
                )
            ),
            "Renderers" => Dict{String, Any}(

            )
        ),
        "Evaluator" => Dict{String, Any}(

        ),
        "Controls" => Dict{String, Any}(
            "Invert camera" => Dict{String, Any}(
                "Panning" => Dict{String, Any}(
                    "X" => nothing,
                    "Y" => nothing
                ),
                "Rotation" => Dict{String, Any}(
                    "X" => nothing,
                    "Y" => nothing
                )
            ),
            "Mouse sensitivity" => Dict{String, Any}(
                    "X" => PropertyHintSlider(0.1,10.0),
                    "Y" => PropertyHintSlider(0.1,10.0)
            ),
            
        ),
        "Geometry" => Dict{String, Any}(

        )
    )
end

function get_setting_hint(path::String)::Union{PropertyHint, Nothing}
    @assert global_settings !== nothing "Settings are uninitialized"
    return get(global_settings.settings_hints, path, nothing)
end

function init_settings(scratch_path::String = "global_settings", toml_file::String="settings.toml", default=default_settings(), edit_hints=settings_hints())
    path = @get_scratch!(scratch_path) *"/"*toml_file
    println("settings path: $path")
    # if file exists -> read file
    if isfile(path)
        d = TOML.parsefile(path)
        global global_settings = GlobalSettings(scratch_path, toml_file, d, edit_hints, Dict(), Dict())
    # else -> generate dict, write file
    else
        global global_settings = GlobalSettings(scratch_path, toml_file, default,edit_hints, Dict(), Dict())
        save_settings()
    end

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
    if haskey(global_settings.modified_notification, path)
        for f::Function in global_settings.modified_notification[path]
            fpair = Pair(f, path)
            if haskey(global_settings.modified_bindings, fpair) && length(global_settings.modified_bindings[fpair]) > 0
                for b in global_settings.modified_bindings[fpair]
                    f(value, b)
                end
            else
                f(value)
            end
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

function on_setting_changed(setting::String, func::Function, binds::Union{Vector, Nothing}=nothing)
    @assert global_settings !== nothing "Settings are uninitialized"
    @assert !isa(get_global_setting(setting), Dict) "Path leads to category, not string"
    func_set = get(global_settings.modified_notification, setting, Set{Function}())
    global_settings.modified_notification[setting] = func_set
    if binds !== nothing
        p = Pair(func, setting)
        if get(global_settings.modified_bindings, p, nothing) ===nothing
            global_settings.modified_bindings[p] = [binds]
        else
            push!(global_settings.modified_bindings[p], binds)
        end
        
    end
    push!(func_set, func)
end

function apply_settings()
    @assert global_settings !== nothing "Settings are uninitialized"
    for n in keys(global_settings.settings)
        _apply_settings(n, global_settings.settings, n)
    end

end

function _apply_settings(setting::String, options::Dict{String, Any}, path::String)
    @assert global_settings !== nothing "Settings are uninitialized"
    if options[setting] isa Dict
        for n in keys(options[setting])
            _apply_settings(n, options[setting], path*"/$n")
        end
    else
        set_global_setting(path, options[setting])
    end
end
