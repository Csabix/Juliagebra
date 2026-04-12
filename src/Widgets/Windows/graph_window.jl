
# ? ---------------------------------
# ! GraphWindow
# ? ---------------------------------

@kwdef mutable struct GraphWindow <: WindowDNA
    _window::Window = Window()
    _selectedState::Int = 1
    _states::Vector{String} = [
        "Single Threaded - Single Frame",
        "Single Threaded - Multiple Frame"
    ]
end

_Window_(self::GraphWindow)::Window = return self._window
getWindowName(::GraphWindow) = return "Graph"

function update!(self::GraphWindow, model::ModelDNA)
    s::Scheduler = getScheduler(model)
    setMode(s,self._selectedState)
end

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
    m::Model = getModel(app)
    graph::DependentGraph = m._graph
    
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

function _renderEvaluationTab(self::GraphWindow, app::AppDNA)
    m::Model = getModel(app)
    sc::Scheduler = getScheduler(m)
    wo::Workers = getWorkers(m)
    sy::Synchronizer = getSynchronizer(m)

    CImGui.Text("Scheduler")
    CImGui.Separator()
    CImGui.Text("taken: $(sc._taken)")
    CImGui.Text("schedule: $([getGraphID(d) for d in dependentsOf(sc._schedule)])")
    CImGui.Text("roots: $([getGraphID(d) for d in sc._roots])")
    CImGui.Spacing()
    CImGui.Spacing()
    CImGui.Spacing()

    CImGui.Text("Select Scheduler mode:")
    
    CImGui.SetNextItemWidth(-1)
    if (CImGui.BeginCombo("##SchedulerModes",self._states[self._selectedState]))
        for idx in eachindex(self._states) 
            state = self._states[idx]
            
            if CImGui.Selectable(state)
                self._selectedState = idx
            end    
        end

        CImGui.EndCombo()
    end

    

    for idx in 0:length(wo)
        w::EvalWorker = wo[idx]
        CImGui.Text("Worker$(idx)")
        CImGui.Separator()

        CImGui.Text("Processed:")
        
        maxVal = 0.0

        if !isempty(w._processed)
            maxVal = maximum(w._processed)
        end
        
        if maxVal < 0.2
            maxVal = 0.2
        elseif maxVal < 0.5
            maxVal = 0.5
        elseif  maxVal < 1.0
            maxVal = 1.0
        elseif maxVal < 1.5
            maxVal = 1.5
        end

        CImGui.PlotHistogram("##$(idx)", w._processed, length(w._processed), 0, "Worker$(idx)", 0.0,maxVal, (-1.0,50.0), sizeof(Float32))
        
        CImGui.Spacing()
        CImGui.Spacing()
        CImGui.Spacing()
    end

    CImGui.Text("Synchronizer")
    CImGui.Separator()
    CImGui.Text("taken: $(sy._taken)")
    
end
