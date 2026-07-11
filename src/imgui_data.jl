
# ? ---------------------------------
# ! ImGuiData
# ? ---------------------------------

# BLUE Thread
Dependent2Observer(app::AppDNA, ::ToggleDependent) = getImGui(app)._pool[1]
Dependent2Observer(app::AppDNA, ::SliderDependent) = getImGui(app)._pool[2]
Dependent2Observer(app::AppDNA, ::TextBoxDependent) = getImGui(app)._pool[3]
Dependent2Observer(app::AppDNA, ::StepperDependent) = getImGui(app)._pool[4]

const _FONT_FOLDER::String = joinpath(pkgdir(@__MODULE__),"src","Fonts")

mutable struct ImGuiData <: ImGuiDNA
    _textFont::Ptr{CImGui.lib.ImFont}
    _iconFont::Ptr{CImGui.lib.ImFont}

    _pool::Vector{GuiRendererDNA}
    _dependents::Vector{GuiDependentDNA}

    _widgets::Vector{ImGuiWidgetDNA}
    _dock::Dock

    # GREEN Thread
    function ImGuiData(app::AppDNA)
        glfwD::GLFWData = getGLFW(app)
        openglD::OpenGLData = getOpenGL(app)
        model::Model = getModel(app)

        imgui_context = CImGui.CreateContext()
        
        CImGui.StyleColorsDark()
        io = CImGui.GetIO()
        CImGui.ImGui_ImplGlfw_InitForOpenGL(glfwD._window.handle, true)
        CImGui.ImGui_ImplOpenGL3_Init("#version 330")
        ImPlot.SetCurrentContext(ImPlot.CreateContext())
        
        #config = CImGui.ImFontConfig()
        #config.OversampleH = 3
        #config.OversampleV = 3
        #config.RasterizerDensity = 2.0

        textFont = CImGui.AddFontFromFileTTF(unsafe_load(io.Fonts),joinpath(_FONT_FOLDER,"Roboto.ttf"),16)
        iconFont = CImGui.AddFontFromFileTTF(unsafe_load(io.Fonts),joinpath(_FONT_FOLDER,"MaterialSymbolsRounded.ttf"),24)

        # ? It's empty because "resetObservers!" initializes it.
        pool::Vector{GuiRendererDNA} = []
        dependents::Vector{GuiDependentDNA} = []

        widgets = Vector{ImGuiWidgetDNA}()
        dock = Dock()

        add!(dock,GuiDependentsWindow())
        add!(dock,Console())
        add!(dock,PerformanceWindow())
        add!(dock,GraphWindow())
        add!(dock,PointsWindow(model,openglD._renderers.point))
        add!(dock,CurvesWindow(model,openglD._renderers.line))
        add!(dock,SurfacesWindow(model,openglD._renderers.triangle))
        add!(dock,FrameTime())
        add!(dock,DarkThemeWindow(Cfloat[0.73f0,0.73f0,0.73f0],openglD._renderers.point,openglD._renderers.line,openglD._renderers.triangle,openglD._renderers.sphere))

        push!(widgets,dock)
        push!(widgets,ResetWidget())
        
        self = new(textFont,iconFont,pool,dependents,widgets,dock)
        
        resetObservers!(self)
        resize!(self,glfwD)
        return self
    end
end

function resetObservers!(self::ImGuiData)
    self._dependents = Vector{GuiDependentDNA}()
    
    # ? Let the garbage collector handle old Observers.
    self._pool::Vector{GuiRendererDNA} = [
        ToggleRenderer(self),   # ? 1
        SliderRenderer(self),   # ? 2
        TextBoxRenderer(self),  # ? 3
        StepperRenderer(self)   # ? 4
    ]
end

function render!(self::ImGuiData,app::AppDNA)

    CImGui.ImGui_ImplOpenGL3_NewFrame()
    CImGui.ImGui_ImplGlfw_NewFrame()
    CImGui.NewFrame()

    for widget in self._widgets
        render(widget,app)
    end

    CImGui.Render()
    CImGui.ImGui_ImplOpenGL3_RenderDrawData(CImGui.GetDrawData())
end

function update!(self::ImGuiData, app::AppDNA)
    tgl::ToggleRenderer = self._pool[1]
    slr::SliderRenderer = self._pool[2]
    txt::TextBoxRenderer = self._pool[3]
    str::StepperRenderer = self._pool[4]
    
    update!(tgl,app)
    update!(slr,app)
    update!(txt,app)
    update!(str,app)


    update!(self._dock._windows[4],getModel(app))
end

function renderBuildingState(::Any, ::AppDNA)
    return nothing
end

function renderBuildingState(self::ImGuiData,app::AppDNA)
    CImGui.ImGui_ImplOpenGL3_NewFrame()
    CImGui.ImGui_ImplGlfw_NewFrame()
    CImGui.NewFrame()

    for widget in self._widgets
        renderBuildingState(widget,app)
    end

    CImGui.Render()
    CImGui.ImGui_ImplOpenGL3_RenderDrawData(CImGui.GetDrawData())
end

function resize!(self::ImGuiData,window::GLFWData)
    for widget in self._widgets
        resize!(widget,Int(window.s_width),Int(window.s_height))
    end
end

function destroy!(::ImGuiData)::Nothing
    ImPlot.DestroyContext(ImPlot.GetCurrentContext())
    CImGui.ImGui_ImplOpenGL3_Shutdown()
    CImGui.ImGui_ImplGlfw_Shutdown()
    CImGui.DestroyContext()
    return nothing
end

