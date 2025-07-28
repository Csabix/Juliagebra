mutable struct ImGuiData
    _shrd::SharedData

    _width::Int
    _height::Int

    _pos_x::Int
    _pos_y::Int

    function ImGuiData(glfwD::GLFWData,openglD::OpenGLData,shrd::SharedData)
        imgui_context = CImGui.CreateContext()
        
        CImGui.StyleColorsDark()
        CImGui.GetIO()
        CImGui.ImGui_ImplGlfw_InitForOpenGL(glfwD._window.handle, true)
        CImGui.ImGui_ImplOpenGL3_Init("#version 330")
        
        self = new(shrd,0,0,0,0)
        resize!(self)

        return self
    end
end

function update!(self::ImGuiData,openglD::OpenGLData,dependentL::DependentGraph,cam::Camera)

    CImGui.ImGui_ImplOpenGL3_NewFrame()
    CImGui.ImGui_ImplGlfw_NewFrame()
    CImGui.NewFrame()
    
    CImGui.SetNextWindowSize((self._width,self._height))
    

    CImGui.Begin("Data Peeker",C_NULL,CImGui.ImGuiWindowFlags_NoResize | CImGui.ImGuiWindowFlags_NoMove)
    
    if (CImGui.IsWindowCollapsed())
        CImGui.SetWindowPos((0,self._shrd._height))
    else
        CImGui.SetWindowPos((self._pos_x,self._pos_y))
    end
    
    
    if CImGui.BeginTabBar("Places")
        if CImGui.BeginTabItem("Shared Data")
            _display!(self,self._shrd)
            CImGui.EndTabItem()
        end
        
        if CImGui.BeginTabItem("Render Items")
            _display!(self,openglD)
            CImGui.EndTabItem()
        end
        
        if CImGui.BeginTabItem("RenderedDependent Items")
            _display!(self,dependentL)
            CImGui.EndTabItem()
        end

        if CImGui.BeginTabItem("Camera")
            _display!(self,cam)
            CImGui.EndTabItem()
        end
    end
    
    CImGui.End()
    CImGui.Render()
    CImGui.ImGui_ImplOpenGL3_RenderDrawData(CImGui.GetDrawData())
end

function slider1(self::T,text::String,min::AbstractFloat,max::AbstractFloat)::T where T
    self_ref = Ref(self)
    CImGui.SliderFloat(text,self_ref,min,max)
    return self_ref[]
end

function slider3(self::Vec3T,text::String,min::AbstractFloat,max::AbstractFloat)::Vec3T
    self_ref = Ref(self)
    CImGui.SliderFloat3(text,self_ref,min,max)
    return self_ref[]
end

function slider1i(self,text::String,min::Integer,max::Integer)
    self_ref = Ref(self)
    CImGui.SliderInt(text,self_ref,min,max)
    return self_ref[]
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

function _display!(self::ImGuiData,dependentL::DependentGraph)
    CImGui.Text("Stored RenderedDependent Objects:")
    i = 1
    for (dependentObject) in dependentL._dependentObjects
        CImGui.Text("$(i) - $(string(dependentObject))")
        #if CImGui.TreeNode()        
        #    CImGui.TreePop()
        #end
        i+=1
    end
end



function _display!(self::ImGuiData,shrd::SharedData)
    CImGui.Text("Selected ID: $(shrd._selectedID)")
    CImGui.Text("Cursor Pos: ($(shrd._mouseX),$(shrd._mouseY))")
    CImGui.Text("Relative cursor: ($(shrd._relMouseX),$(shrd._relMouseY))")
    CImGui.Text("Cursor moved: $(shrd._mouseMoved)")
    CImGui.Text("Window Dimensions: ($(shrd._width),$(shrd._height))")
    CImGui.Text("Delta Time: $(shrd._deltaTime)")

    fpsApprx = 1.0/shrd._deltaTime

    CImGui.Text("FPS approx: $(fpsApprx)")

    #shrd._selectedGizmo = slider1i(shrd._selectedGizmo,"GizmoID",1,3)

end

function _display!(self::ImGuiData,openglD::OpenGLData)

    CImGui.Text("Background Color:")

    #r = slider(openglD._backgroundCol.x,"R-(Bckg)",0.0,1.0)
    #g = slider(openglD._backgroundCol.y,"G-(Bckg)",0.0,1.0)
    #b = slider(openglD._backgroundCol.z,"B-(Bckg)",0.0,1.0)
    #openglD._backgroundCol = Vec3(r,g,b)
    openglD._backgroundCol = slider3(openglD._backgroundCol,"RGB-(Bckg)",0.0,1.0)
    openglD._gizmoGL._pos = slider3(openglD._gizmoGL._pos,"Gizmo-(x,y,z)",-10.0,10.0)

    CImGui.Text("Render Offices:")
    i = 1
    for (key,office) in openglD._renderOffices
        if CImGui.TreeNode("$(i) - $(string(key))")
            j = 1
            for employee in office
                CImGui.Text("$(j) - $(string(employee))")
                j+=1
            end
            CImGui.TreePop()
        end
        i+=1
    end



end

function resize!(self::ImGuiData)
    self._width = self._shrd._width
    self._height = floor(self._shrd._height * 0.3)
    self._pos_y = self._shrd._height - self._height
end

function destroy!(self::ImGuiData)

    CImGui.ImGui_ImplOpenGL3_Shutdown()
    CImGui.ImGui_ImplGlfw_Shutdown()
    CImGui.DestroyContext()

end

