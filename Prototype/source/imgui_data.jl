mutable struct ImGuiData
    _shrd::SharedData

    function ImGuiData(glfwD::GLFWData,openglD::OpenGLData,shrd::SharedData)
        imgui_context = CImGui.CreateContext()
        CImGui.StyleColorsDark()
        CImGui.GetIO()
        CImGui.ImGui_ImplGlfw_InitForOpenGL(glfwD._window.handle, true)
        # ! This Bloody bugger just copes than pastes #version 330 into the shader.
        # ! What an absolute jokester this library is.
        #println(unsafe_string(glGetString(GL_VERSION)))
        CImGui.ImGui_ImplOpenGL3_Init("#version 330")
        new(shrd)
    end
end

function update!(self::ImGuiData,openglD::OpenGLData,algebraL::AlgebraLogic)

    CImGui.ImGui_ImplOpenGL3_NewFrame()
    CImGui.ImGui_ImplGlfw_NewFrame()
    CImGui.NewFrame()
    CImGui.Begin("Data Peeker")
    if CImGui.BeginTabBar("Places")
        if CImGui.BeginTabItem("Shared Data")
            _display!(self,self._shrd)
            CImGui.EndTabItem()
        end
        
        if CImGui.BeginTabItem("Render Items")
            _display!(self,openglD)
            CImGui.EndTabItem()
        end
        
        if CImGui.BeginTabItem("Algebra Items")
            _display!(self,algebraL)
            CImGui.EndTabItem()
        end
    end
    
    CImGui.End()
    CImGui.Render()
    CImGui.ImGui_ImplOpenGL3_RenderDrawData(CImGui.GetDrawData())
end

function _display!(self::ImGuiData,algebraL::AlgebraLogic)
    CImGui.Text("Stored Alfebra Objects:")
    i = 1
    for (algebraObject) in algebraL._algebraObjects
        if CImGui.TreeNode("$(i) - $(string(algebraObject))")
            
            CImGui.TreePop()
        end
        i+=1
    end
end



function _display!(self::ImGuiData,shrd::SharedData)
    CImGui.Text("Selected ID: $(shrd._selectedID)")
    CImGui.Text("Cursor Pos: ($(shrd._mouseX),$(shrd._mouseY))")
    CImGui.Text("Window Dimensions: ($(shrd._width),$(shrd._height))")
    CImGui.Text("Delta Time: $(shrd._deltaTime)")
end

function _display!(self::ImGuiData,openglD::OpenGLData)

    CImGui.Text("Background Color:")
    r = Ref(openglD._backgroundCol.x)
    g = Ref(openglD._backgroundCol.y)
    b = Ref(openglD._backgroundCol.z)

    CImGui.SliderFloat("R-(Bckg)",r,0.0,1.0)
    CImGui.SliderFloat("G-(Bckg)",g,0.0,1.0)
    CImGui.SliderFloat("B-(Bckg)",b,0.0,1.0)
    
    

    openglD._backgroundCol = Vec3(r[],g[],b[])


    CImGui.Text("Render Offices:")
    i = 1
    for (key,office) in openglD._renderOffices
        if CImGui.TreeNode("$(i) - $(string(key))")
            j = 1
            for employee in office
                if CImGui.TreeNode("$(j) - $(string(employee))")
                    CImGui.Text(string(employee._asset))
                    CImGui.TreePop()
                end
                j+=1
            end
            CImGui.TreePop()
        end
        i+=1
    end



end

function destroy!(self::ImGuiData)

    CImGui.ImGui_ImplOpenGL3_Shutdown()
    CImGui.ImGui_ImplGlfw_Shutdown()
    CImGui.DestroyContext()

end

