
# ? ---------------------------------
# ! GraphWindow
# ? ---------------------------------

@kwdef mutable struct GraphWindow <: WindowDNA
    _window::Window = Window()
end

_Window_(self::GraphWindow)::Window = return self._window
getWindowName(::GraphWindow) = return "Graph"

function renderContent(self::GraphWindow, app::AppDNA)
    if CImGui.BeginTabBar("Graph")
        if CImGui.BeginTabItem("Dependents")
            _renderDependentsTab(self,app)
            CImGui.EndTabItem()
        end

        if CImGui.BeginTabItem("Evaluation")
            _renderEvaluationTab(self,app)
            CImGui.EndTabItem()
        end

        CImGui.EndTabBar()
    end
end

function _renderDependentsTab(::GraphWindow, app::AppDNA)
    graph::DependentGraph = getGraph(app)
    
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

function _renderEvaluationTab(::GraphWindow, app::AppDNA)
    sc::Scheduler = getScheduler(app)
    wo::GraphWorker = getWorker(app)
    sy::Synchronizer = getSynchronizer(app)

    CImGui.Text("Scheduler")
    CImGui.Separator()
    CImGui.Text("taken: $(sc._taken)")
    CImGui.Text("schedule: $([getGraphID(d) for d in dependentsOf(sc._schedule)])")
    CImGui.Text("roots: $([getGraphID(d) for d in sc._roots])")
    CImGui.Spacing()
    CImGui.Spacing()
    CImGui.Spacing()

    CImGui.Text("Worker")
    CImGui.Separator()
    CImGui.Text("taken: $(wo._taken)")
    CImGui.Spacing()
    CImGui.Spacing()
    CImGui.Spacing()

    CImGui.Text("Synchronizer")
    CImGui.Separator()
    CImGui.Text("taken: $(sy._taken)")
    
end