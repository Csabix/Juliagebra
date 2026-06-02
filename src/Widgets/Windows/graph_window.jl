
# ? ---------------------------------
# ! GraphWindow
# ? ---------------------------------

@kwdef mutable struct GraphWindow <: WindowDNA
    _window::Window = Window()
    _renderState::Int = 1
    _updateState::Int = 1
    _workerIDs::Vector{Vector{Int}} = [[] for _ in 0:MAX_WORKER_NUM()]
    _workerTimes::Vector{Vector{Float32}} = [[] for _ in 0:MAX_WORKER_NUM()]
    _workerSum::Vector{Float64} = [0.0 for _ in 0:MAX_WORKER_NUM()]
    _workerPlotIdx::Vector{Int64} = [0 for _ in 0:MAX_WORKER_NUM()]
end

_Window_(self::GraphWindow)::Window = return self._window
getWindowName(::GraphWindow) = return "Graph"

function update!(self::GraphWindow, model::ModelDNA)
    s::Scheduler = getScheduler(model)
    self._updateState = self._renderState
    setMode(s, self._updateState)
    
    if isVisible(self)
        _update1(self, getMode(s, self._updateState), model)
    end
end

function _update1(self::GraphWindow, ::SingleFrameSingleThread, model::ModelDNA)
    _update2(self, 0, model)
end

function _update1(self::GraphWindow, ::Union{SingleFrameTwoThreads, MultipleFramesSingleThread}, model::ModelDNA)
    _update2(self, 1, model)
end

function _update1(self::GraphWindow, ::Union{SingleFrameMultipleThreads, MultipleFramesMultipleThreads}, model::ModelDNA)
    for idx in 1:length(getWorkers(model)) 
        _update2(self, idx, model)
    end
end

function _update2(self::GraphWindow, idx::Int, model::ModelDNA)
    _ids::Vector{Int} = self._workerIDs[idx+1]
    _times::Vector{Float32} = self._workerTimes[idx+1]
    
    Base.resize!(_ids,0)
    Base.resize!(_times,0)
    
    w::EvalWorker = getWorkers(model)[idx]
    wIDs::Vector{Int} = getProcessedIDs(w)
    wTimes::Vector{Float64} = getProcessedTimes(w)
    
    for id in wIDs 
        push!(_ids, id)
    end

    for t in wTimes
        push!(_times,Float32(t))
    end

    self._workerSum[idx+1] = sum(wTimes)
end

function renderContent(self::GraphWindow, app::AppDNA)
    if CImGui.BeginTabBar("Graph")
        if CImGui.BeginTabItem("Evaluation")
            _renderEvaluationTab(self,app)
            CImGui.EndTabItem()
        end
        
        if CImGui.BeginTabItem("Dependents")
            _renderDependentsTab(self,app)
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

    CImGui.Text("Synchronizer")
    CImGui.Separator()
    CImGui.Text("taken: $(sy._taken)")
    CImGui.Spacing()
    CImGui.Spacing()
    CImGui.Spacing()

    CImGui.Text("Select Scheduler mode:")
    
    states::Vector{String} = ["$(getMode(sc,idx))" for idx in 1:getModesLength(sc)]

    CImGui.SetNextItemWidth(-1)
    if (CImGui.BeginCombo("##SchedulerModes", states[self._updateState]))
        for idx in eachindex(states)             
            if CImGui.Selectable(states[idx])
                self._renderState = idx
            end    
        end

        CImGui.EndCombo()
    end

    _renderEvaluationTab1(self, getMode(sc, self._updateState), m)
end

function _renderEvaluationTab1(self::GraphWindow, ::SingleFrameSingleThread, model::ModelDNA)
    _renderWorker(self, 0, model)
end

function _renderEvaluationTab1(self::GraphWindow, ::Union{SingleFrameTwoThreads, MultipleFramesSingleThread}, model::ModelDNA)
    _renderWorker(self, 1, model)
end

function _renderEvaluationTab1(self::GraphWindow, ::Union{SingleFrameMultipleThreads, MultipleFramesMultipleThreads}, model::ModelDNA)
    for idx in 1:length(getWorkers(model))
        _renderWorker(self, idx, model)
    end
end

function _renderWorker(self::GraphWindow, idx::Int, model::ModelDNA)
    CImGui.Separator()

    _ids::Vector{Int} = self._workerIDs[idx+1]
    _times::Vector{Float32} = self._workerTimes[idx+1]

    maxVal::Float32 = Float32(0.0)
    !isempty(_times) ? maxVal = maximum(_times) : nothing
    CImGui.PlotHistogram("##$(idx)", _times, length(_times), 0, "Worker$(idx)", 0.0, maxVal, (-1.0,50.0), sizeof(Float32))
        
    #if !isempty(_ids)
    #    CImGui.Text("Plot id to graphID:")
    #    CImGui.SameLine()
    #    idxx = idx+1
    #
    #    plotIdx = input1i(self._workerPlotIdx[idxx], "##plotIdx$(idx)" , 1, 10)
    #    self._workerPlotIdx[idxx] = !isnothing(plotIdx) ? clamp(plotIdx, 0, length(_ids)-1) : clamp(self._workerPlotIdx[idxx], 0, length(_ids)-1)
    #    # TODO: Crashes if Graph was Emptied before.
    #    d::DependentDNA = getDependent(getGraph(model),_ids[self._workerPlotIdx[idxx]+1])
    #   
    #    txtStr = replace("$(typeof(d))",r"Juliagebra\.|JuliaGLM\." => "")
    #    CImGui.Text("Node: $(txtStr)")
    #    
    #    CImGui.Text("graphID: $(getGraphID(d))")
    #else
    #    CImGui.Text("Empty schedule!")
    #end

    CImGui.Text("Processed: $(length(_ids))")
    CImGui.Text("Slowest time: $(maxVal)")
    CImGui.Text("Sum time: $(self._workerSum[idx+1])")
    
    CImGui.Spacing()
    CImGui.Spacing()
    CImGui.Spacing()
end