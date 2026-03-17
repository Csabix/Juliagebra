
# ? ---------------------------------
# ! ImGuiData
# ? ---------------------------------

# BLUE Thread
Dependent2Observer(app::AppDNA,::ToggleDependent) = getImGui(app)._pool[1]
Dependent2Observer(app::AppDNA,::SliderDependent) = getImGui(app)._pool[2]
Dependent2Observer(app::AppDNA,::TextBoxDependent) = getImGui(app)._pool[3]

const _FONT_FOLDER::String = joinpath(pkgdir(@__MODULE__),"src","Fonts")

mutable struct ImGuiData <: ImGuiDNA
    _shrd::SharedData
    
    _io::Ptr{CImGui.lib.ImGuiIO}

    _textFont::Ptr{CImGui.lib.ImFont}
    _iconFont::Ptr{CImGui.lib.ImFont}

    _width::Int
    _height::Int

    _pos_x::Int
    _pos_y::Int

    _pool::Vector{GuiRendererDNA}

    _widgets::Vector{ImGuiWidgetDNA}
    _dock::Dock

    # GREEN Thread
    function ImGuiData(app::AppDNA)
        
        glfwD::GLFWData = getGLFW(app)
        openglD::OpenGLData = getOpenGL(app)
        shrd::SharedData = getShrd(app)
        graph::DependentGraphDNA = getGraph(app)

        imgui_context = CImGui.CreateContext()
        
        CImGui.StyleColorsDark()
        io = CImGui.GetIO()
        CImGui.ImGui_ImplGlfw_InitForOpenGL(glfwD._window.handle, true)
        CImGui.ImGui_ImplOpenGL3_Init("#version 330")
        
        #config = CImGui.ImFontConfig()
        #config.OversampleH = 3
        #config.OversampleV = 3
        #config.RasterizerDensity = 2.0

        textFont = CImGui.AddFontFromFileTTF(unsafe_load(io.Fonts),joinpath(_FONT_FOLDER,"Roboto.ttf"),16)
        iconFont = CImGui.AddFontFromFileTTF(unsafe_load(io.Fonts),joinpath(_FONT_FOLDER,"MaterialSymbolsRounded.ttf"),24)

        pool::Vector{GuiRendererDNA} = [
            ToggleRenderer(), # ? 1
            SliderRenderer(), # ? 2
            TextBoxRenderer() # ? 3
        ]
        
        widgets = Vector{ImGuiWidgetDNA}()
        dock = Dock(shrd._width,shrd._height)

        add!(dock,GuiDependentsWindow(pool))
        add!(dock,DataPeeker(shrd))
        add!(dock,Console())
        add!(dock,PerformanceWindow())
        add!(dock,GraphViewerWindow(graph))

        push!(widgets,dock)

        self = new(shrd,io,textFont,iconFont,0,0,0,0,pool,widgets,dock)
        
        push!(self._widgets,ResetWidget(self))

        resize!(self)

        return self
    end
end

function SingleGuiRendererByGuiDependentsWindow(self::ImGuiData,t::Type{T})::T where T<:GuiRendererDNA
    myVector = get!(self._guiDependentsWindow._guiRenderers,T,Vector{T}())

    if(length(myVector)!=1)
        push!(myVector,T())
    end

    return myVector[1]

end

@inline function captures_mouse(self::ImGuiData)
    io = unsafe_load(self._io)
    return io.WantCaptureMouse
end

@inline function captures_keyboard(self::ImGuiData)
    io = unsafe_load(self._io)
    return io.WantCaptureKeyboard
end

function update!(self::ImGuiData)

    CImGui.ImGui_ImplOpenGL3_NewFrame()
    CImGui.ImGui_ImplGlfw_NewFrame()
    CImGui.NewFrame()

    for widget in self._widgets
        render(widget)
    end

    CImGui.Render()
    CImGui.ImGui_ImplOpenGL3_RenderDrawData(CImGui.GetDrawData())
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

function _display!(self::ImGuiData,cam::Camera)
    cam._fov = slider1(cam._fov,"Fov",0.0,150.0)
    cam._at = slider3(cam._at,"At",-10.0,10.0)
    cam._eye = slider3(cam._eye,"Eye",-50.0,50.0)
    cam._leftRightRot = slider1(cam._leftRightRot,"Left-Right",0.0,360.0)
    cam._upDownRot = slider1(cam._upDownRot,"Up-Down",0.0,360.0)
    cam._rotateSensitivity = slider1(cam._rotateSensitivity,"Rotate sensitivity",0.0,500.0)
    cam._zoom = slider1(cam._zoom,"Zoom",0.0,10.0)
    cam._zoomSensitivity = slider1(cam._zoomSensitivity,"Zoom sensitivity",0.0,100.0)
    cam._moveSpeed = slider1(cam._moveSpeed,"Movement speed",0.0,10.0)
end

function _display!(self::ImGuiData,dependentL::DependentGraphDNA)
    CImGui.Text("Stored RenderedDependent Objects:")
    i = 1
    for (dependentObject) in _DependentGraph(dependentL)._dependentObjects
        CImGui.Text("$(i) - $(string(dependentObject))")
        #if CImGui.TreeNode()        
        #    CImGui.TreePop()
        #end
        i+=1
    end
end

function _display!(self::ImGuiData,openglD::OpenGLData)

    CImGui.Text("Background Color:")

    #r = slider(openglD._backgroundCol.x,"R-(Bckg)",0.0,1.0)
    #g = slider(openglD._backgroundCol.y,"G-(Bckg)",0.0,1.0)
    #b = slider(openglD._backgroundCol.z,"B-(Bckg)",0.0,1.0)
    #openglD._backgroundCol = Vec3(r,g,b)
    openglD._backgroundCol = slider3(openglD._backgroundCol,"RGB-(Bckg)",0.0,1.0)
    openglD._gizmoGL._pos = slider3(openglD._gizmoGL._pos,"Gizmo-(x,y,z)",-10.0,10.0)

    CImGui.Text("Renderers:")
    for renderer in openglD._renders
        if renderer !== nothing
            CImGui.Text("$(string(renderer))")
        end
    end



end

function resize!(self::ImGuiData)
    self._width = self._shrd._width
    self._height = floor(self._shrd._height * 0.3)
    self._pos_y = self._shrd._height - self._height

    for widget in self._widgets
        resize!(widget,self._shrd._width,self._shrd._height)
    end
end

function destroy!(self::ImGuiData)

    CImGui.ImGui_ImplOpenGL3_Shutdown()
    CImGui.ImGui_ImplGlfw_Shutdown()
    CImGui.DestroyContext()

end

