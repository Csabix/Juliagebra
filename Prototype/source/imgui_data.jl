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

function update!(self::ImGuiData,openglD::OpenGLData)

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

            CImGui.EndTabItem()
        end
    end
    
    CImGui.End()
    CImGui.Render()
    CImGui.ImGui_ImplOpenGL3_RenderDrawData(CImGui.GetDrawData())
end

function _display!(self::ImGuiData,shrd::SharedData)
    CImGui.Text("Selected ID by cursor: $(shrd._selectedID)")
    CImGui.Text("cursor pos: ($(shrd._mouseX),$(shrd._mouseY))")
    CImGui.Text("Window dimension: ($(shrd._width),$(shrd._height))")
end

function _display!(self::ImGuiData,openglD::OpenGLData)

    CImGui.Text("Background Color:")    
    CImGui.SliderFloat3("RGB",Ref(openglD._backgroundCol),0.0,1.0)
        
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

