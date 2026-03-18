# ? ---------------------------------
# ! GraphViewerWindow
# ? ---------------------------------

mutable struct GraphViewerWindow <: WindowDNA
    _window::Window

    function GraphViewerWindow()
        new(Window())
    end
end

_Window_(self::GraphViewerWindow)::Window = return self._window
getWindowName(::GraphViewerWindow) = return "GraphViewer"

function renderContent(::GraphViewerWindow, app::AppDNA)
    graph = getGraph(app)
    
    if (CImGui.BeginTable("Dependents",3, 
        CImGui.ImGuiTableFlags_Borders |
        CImGui.ImGuiTableFlags_RowBg |
        CImGui.ImGuiTableFlags_ScrollX))
    
        CImGui.TableSetupColumn("ID")
        CImGui.TableSetupColumn("Type")
        CImGui.TableSetupColumn("Parents")
        CImGui.TableHeadersRow()

        for dependent in getNodes(graph)
            CImGui.TableNextRow()

            CImGui.TableNextColumn()
            CImGui.Text("$(getGraphID(dependent))")

            CImGui.TableNextColumn()
            txtStr = replace("$(typeof(dependent))",r"Juliagebra\.|JuliaGLM\." => "")
            CImGui.Text(txtStr)

            CImGui.TableNextColumn()
            txtStr = ""
            for parent in getGraphParents(dependent)
                txtStr*="$(getGraphID(parent)),"
            end
            txtStr = "[" * txtStr[1:(end-1)] * "]"
            CImGui.Text(txtStr)
        end

        CImGui.EndTable()
    end
end