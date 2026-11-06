using Scratch
import TOML

struct GlobalSettings
    scratch_path::String
    toml_file::String
    settings::Dict{String, Any}
    settings_hints::Dict{String, Any}
    modified_notification::Dict{String, Set{Function}}
    modified_bindings::Dict{Pair{Function, String}, Vector{Union{Vector{Any}, Nothing}}}
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
        _apply_default(d, default)
        global global_settings = GlobalSettings(scratch_path, toml_file, d, edit_hints, Dict(), Dict())
    # else -> generate dict
    else
        global global_settings = GlobalSettings(scratch_path, toml_file, default, edit_hints, Dict(), Dict())
    end
    save_settings()
end

function _apply_default(settings::Dict, default::Dict)
    for k in keys(default)
        if !haskey(settings, k) # loaded settings do not have expected value
            settings[k] = default[k]
        elseif default[k] isa Dict # expected category
            if settings[k] isa Dict # got category -> check category
                _apply_default(settings[k], default[k])
            else # got value -> replace with default category
                settings[k] = default[k]
            end
        elseif settings[k] isa Dict # expected value, got category -> replace with default value
            settings[k] = default[k]
        end
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
    
    if !haskey(global_settings.modified_notification, path)
        return 
    end

    # callback
    for f::Function in global_settings.modified_notification[path]
        fpair = Pair(f, path)
        if !haskey(global_settings.modified_bindings, fpair) || length(global_settings.modified_bindings[fpair]) == 0
            continue
        end

        for b in global_settings.modified_bindings[fpair]
            if b !== nothing
                f(value, b)
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

function on_setting_changed(func::Function, setting::String, binds::Union{Vector, Nothing}=nothing)
    @assert global_settings !== nothing "Settings are uninitialized"
    @assert !isa(get_global_setting(setting), Dict) "Path leads to category, not string"
    func_set = get(global_settings.modified_notification, setting, Set{Function}())
    global_settings.modified_notification[setting] = func_set
    p = Pair(func, setting)
    if get(global_settings.modified_bindings, p, nothing) === nothing
        global_settings.modified_bindings[p] = [binds]
    else
        push!(global_settings.modified_bindings[p], binds)
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
