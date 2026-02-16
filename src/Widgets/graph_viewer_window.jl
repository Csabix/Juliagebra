# ? ---------------------------------
# ! GraphViewerWindow
# ? ---------------------------------

mutable struct GraphViewerWindow <: WindowDNA
    _window::Window
    _graph::DependentGraphDNA
end

GraphViewerWindow(graph::DependentGraphDNA) = return GraphViewerWindow(Window(),graph)

_Window_(self::GraphViewerWindow)::Window = return self._window
getWindowName(self::GraphViewerWindow) = return "GraphViewer"

function renderContent(self::GraphViewerWindow)
    if (CImGui.BeginTable("Dependents",3, 
        CImGui.ImGuiTableFlags_Borders |
        CImGui.ImGuiTableFlags_RowBg |
        CImGui.ImGuiTableFlags_ScrollX))
    
        CImGui.TableSetupColumn("ID")
        CImGui.TableSetupColumn("Type")
        CImGui.TableSetupColumn("Parents")
        CImGui.TableHeadersRow()

        for dependent in getNodes(self._graph)
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