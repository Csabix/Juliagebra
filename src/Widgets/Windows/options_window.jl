using CImGui.CSyntax.CStatic
mutable struct OptionsWindow <: WindowDNA
    _window::Window
    selected_category::Int
    input_record_mode::Union{Nothing, InputAction}
    function OptionsWindow()
        new(Window(), -1, nothing)
    end
end

_Window_(self::OptionsWindow)::Window = self._window
getWindowName(self::OptionsWindow) = "Options"

function _render_option(name::String, subcategory::Dict{String, Any}, defaults::Dict{String, Any}, hints::Union{Dict{String, Any}, Nothing}, path::String)
    if CImGui.TreeNode(name)
        options = collect(keys(subcategory))
        indices = sortperm(options)
        for i in indices
            o = options[i]
            v = subcategory[o]
            h = hints !== nothing ? get(hints, o, nothing) : nothing
            if v isa Dict
                _render_option(o, v, defaults[o], h, path*"/$o")
            else
                result = input_property(o,v, h)
                if v!=result
                    set_global_setting(path*"/$o", result)
                end
                if result != defaults[o]
                    CImGui.SameLine()
                    if CImGui.Button("Reset##$path/$o")
                        set_global_setting(path*"/$o", defaults[o])
                    end
                end

            end
        end
        CImGui.TreePop()
    end
end

function _render_keybinds(window::OptionsWindow, inputs::Inputs)
    if window.input_record_mode ===nothing
        actions = collect(instances(InputAction))
        idx = sortperm(actions)
        for i in idx
            a = actions[i]
            if CImGui.TreeNode("$a")
                if haskey(inputs.reverse_action_map, a)
                    for kb in inputs.reverse_action_map[a]
                        CImGui.Text(keypress_name(kb[1], kb[2]))
                        CImGui.SameLine()
                        if CImGui.Button("Delete##$kb")
                            delete_action_input(inputs, kb[2], kb[1])
                        end
                    end
                end
                if CImGui.Button("Add Keybind")
                    window.input_record_mode = a
                    inputs.pause_key_callbacks = true
                end
                CImGui.TreePop()
            end
        end
    else
        action = window.input_record_mode
        CImGui.Text("Binding input to $action")
        if CImGui.Button("Cancel")
            window.input_record_mode = nothing
            inputs.pause_key_callbacks = false
            return
        end
        key = keys(inputs.keys_pressed)
        for k in key
            if !is_valid_key(k)
                continue
            end
            event = inputs.keys_pressed[k]
            set_action_input(inputs, action, event.scancode, event.key_mod)
            window.input_record_mode = nothing
            inputs.pause_key_callbacks = false
        end 
        
    end
end

function render(self::OptionsWindow, app::AppDNA)
    if (isVisible(self))
        isVisible_Ref = Ref(isVisible(self))

        CImGui.Begin(getWindowName(self),isVisible_Ref)
        
        renderContent(self, app)

        CImGui.End()

        setVisible(self,isVisible_Ref[])
    else
        self.input_record_mode = nothing
        self.selected_category = -1
        app._inputs.pause_key_callbacks = false
    end
end

function renderContent(self::OptionsWindow, app::AppDNA)
    @assert global_settings !== nothing "Settings are uninitialized"

    CImGui.BeginChild("Option Categories",(CImGui.GetContentRegionAvail().x * 0.2, 0.0))

    categories = collect(keys(global_settings.settings))
    category_indices = sortperm(categories)
    for i in category_indices
        if CImGui.Selectable(categories[i], self.selected_category == i)
            self.selected_category = i
        end
    end

    CImGui.Separator()
    if CImGui.Selectable("Edit keybinds", self.selected_category == -2)
            self.selected_category = -2
    end
    CImGui.EndChild()

    CImGui.SameLine()
    CImGui.BeginChild("Options", (0.0,0.0))

    if checkbounds(Bool, categories, self.selected_category)
        i = self.selected_category
        _render_option(categories[i], global_settings.settings[categories[i]], default_settings()[categories[self.selected_category]], global_settings.settings_hints[categories[i]], categories[i])
    elseif self.selected_category == -2
        _render_keybinds(self, app._inputs)
    end
    CImGui.EndChild()
end