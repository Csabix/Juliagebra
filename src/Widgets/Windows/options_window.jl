using CImGui.CSyntax.CStatic
mutable struct OptionsWindow <: WindowDNA
    _window::Window
    categories::Vector{String}
    subcategories::Vector{String}
    cat_segments::Dict
    reverse_cat_segments::Dict
    selected_subcategory::Int
    input_record_mode::Union{Nothing, InputAction}
    function OptionsWindow()
        categories = collect(keys(global_settings.settings))
        subcategories = []
        cat_segments = Dict()
        reverse_cat_segments = Dict()
        category_indices = sortperm(categories)
        begin
            a = 1
            b = 1
            for i in category_indices
            
                k = collect(keys(global_settings.settings[categories[i]]))

                for j in sortperm(k)
                    push!(subcategories, k[j])
                    reverse_cat_segments[a+j-1] = categories[i]
                    b+=1
                end
                cat_segments[categories[i]] = (a,b-1)
                reverse_cat_segments[(a,b-1)] = categories[i]
                a=b
                b=a
            end
        end
        new(Window(), categories, subcategories, cat_segments, reverse_cat_segments, -1, nothing)
    end
end

_Window_(self::OptionsWindow)::Window = self._window
getWindowName(self::OptionsWindow) = "Options"

function _render_option(name::String, subcategory::Dict{String, Any}, defaults::Dict{String, Any}, hints::Union{Dict{String, Any}, Nothing}, path::String)
    CImGui.Text(name)
    CImGui.Indent()
        options = collect(keys(subcategory))
        indices = sortperm(options)
        for i in indices
            o = options[i]
            v = subcategory[o]
            h = hints !== nothing ? get(hints, o, nothing) : nothing
            if v isa Dict
                _render_option(o, v, defaults[o], h, path*"/$o")
            else
                result = input_property(o*"##$path/$i",v, h)
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
        
    CImGui.Unindent()
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
            set_action_input(inputs, action, k, event.key_mod)
            window.input_record_mode = nothing
            inputs.pause_key_callbacks = false
            return
        end
        button = keys(inputs.mouse_pressed)
        for k in button
            event = inputs.mouse_pressed[k]
            set_action_input(inputs, action, k, event.key_mod)
            window.input_record_mode = nothing
            inputs.pause_key_callbacks = false
            return
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
        self.selected_subcategory = -1
        app._inputs.pause_key_callbacks = false
    end
end

function renderContent(self::OptionsWindow, app::AppDNA)
    @assert global_settings !== nothing "Settings are uninitialized"

    CImGui.BeginChild("Option Categories",(CImGui.GetContentRegionAvail().x * 0.2, 0.0))

    category_indices = sortperm(self.categories)
    for i in category_indices
        if CImGui.TreeNode(self.categories[i])
            c = self.categories[i]
            subs = self.cat_segments[c]

            for j in subs[1]:subs[2]
                sc = self.subcategories[j]
                if CImGui.Selectable("$sc##$j", self.selected_subcategory == j)
                    self.selected_subcategory = j
                end
            end
            CImGui.TreePop()
        end
    end

    CImGui.Separator()
    if CImGui.Selectable("Edit keybinds", self.selected_subcategory == -2)
            self.selected_subcategory = -2
    end
    CImGui.EndChild()
    
    CImGui.SameLine()
    CImGui.BeginChild("Options", (0.0,0.0))

    if checkbounds(Bool, self.subcategories, self.selected_subcategory)
        i = self.selected_subcategory
        cat = self.reverse_cat_segments[i]
        subcat = self.subcategories[i]
        settings = global_settings.settings[cat][subcat]
        k = collect(keys(settings))
        idx = sortperm(k)
        
            
            _render_option("$cat/$subcat", settings, default_settings()[cat][subcat], global_settings.settings_hints[cat][subcat], "$cat/$subcat")
        
        
    elseif self.selected_subcategory == -2
        _render_keybinds(self, app._inputs)
    end
    CImGui.EndChild()
end