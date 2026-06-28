K::Vec4D = Vec4D(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);

function hsv2rgb(c::Vec3D)::Vec3D
    Kxxx = Vec3D(K.x)
    cxxx = Vec3D(c.x)
    Kxyz = Vec3D(K.x, K.y, K.z)
    Kwww = Vec3D(K.w)

    ff = cxxx + Kxyz

    a = clamp.(abs.(mod.(ff, 1) * 6.0 - Kwww) - Kxxx, 0.0, 1.0)
    b = (1.0-c.y) * Kxxx + c.y * a
    return c.z * b
end

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
    _graphID2workerIDX::Dict{Int,Int} = Dict{Int,Int}()
end

_Window_(self::GraphWindow)::Window = return self._window
getWindowName(::GraphWindow) = return "Graph"

function update!(self::GraphWindow, model::Model)
    s::Scheduler = getScheduler(model)
    self._updateState = self._renderState
    setMode(s, self._updateState)

    if isVisible(self)
        empty!(self._graphID2workerIDX)
        _update1(self, getMode(s, self._updateState), model)
    end
end

function _update1(self::GraphWindow, ::SingleFrameSingleThread, model::Model)
    _update2(self, 0, model)
end

function _update1(self::GraphWindow, ::Union{SingleFrameTwoThreads, MultipleFramesSingleThread}, model::Model)
    _update2(self, 1, model)
end

function _update1(self::GraphWindow, ::Union{SingleFrameMultipleThreads, MultipleFramesMultipleThreads}, model::Model)
    for idx in 1:length(getWorkers(model)) 
        _update2(self, idx, model)
    end
end

function _update2(self::GraphWindow, idx::Int, model::Model)
    _ids::Vector{Int} = self._workerIDs[idx+1]
    _times::Vector{Float32} = self._workerTimes[idx+1]
    
    Base.resize!(_ids,0)
    Base.resize!(_times,0)
    
    w::EvalWorker = getWorkers(model)[idx]
    wIDs::Vector{Int} = getProcessedIDs(w)
    wTimes::Vector{Float64} = getProcessedTimes(w)
    
    for id in wIDs 
        push!(_ids, id)
        self._graphID2workerIDX[id] = idx
    end

    for t in wTimes
        push!(_times,Float32(t))
    end

    self._workerSum[idx+1] = sum(wTimes)
end

function renderContent(self::GraphWindow, app::AppDNA)
    if CImGui.BeginTable("Graph",2,
        CImGui.ImGuiTableFlags_SizingStretchSame)

        CImGui.TableNextColumn()
        _renderEvaluationTab(self,app)

        CImGui.TableNextColumn()
        _renderDependentsTab(self,app)

        CImGui.EndTable()
    end
end

idx2hue(self::GraphWindow, idx::Int)::Float64 = idx/(length(self._workerIDs)-1.0)
idx2basecol(self::GraphWindow, idx::Int)::Vec3D     = return hsv2rgb(Vec3D(idx2hue(self,idx), 0.90, 0.85))
idx2hoveredcol(self::GraphWindow, idx::Int)::Vec3D  = return hsv2rgb(Vec3D(idx2hue(self,idx), 0.65, 1.00))

function _renderDependentsTab(self::GraphWindow, app::AppDNA)
    m::Model = getModel(app)
    graph::DependentGraph = m._graph
    
    if (CImGui.BeginTable("Dependents",3, 
        CImGui.ImGuiTableFlags_RowBg |
        CImGui.ImGuiTableFlags_ScrollX))
    
        CImGui.TableSetupColumn("ID")
        CImGui.TableSetupColumn("Type")
        CImGui.TableSetupColumn("Parents")
        CImGui.TableHeadersRow()

        for dependent in getNodes(graph)
            CImGui.TableNextRow()

            id::Int = getGraphID(dependent)
            col::Vec3D = id in keys(self._graphID2workerIDX) ? idx2basecol(self,self._graphID2workerIDX[id]) : Vec3D(1.0,1.0,1.0)
            color::Tuple = (col...,1.0)

            CImGui.TableNextColumn()
            CImGui.TextColored(color, "$(id)")

            CImGui.TableNextColumn()
            txtStr = replace("$(typeof(dependent))",r"Juliagebra\.|JuliaGLM\." => "")
            CImGui.TextColored(color, txtStr)
            
            CImGui.TableNextColumn()
            txtStr = ""
            for parent in getGraphParents(dependent)
                txtStr*="$(getGraphID(parent)),"
            end
            txtStr = "[" * txtStr[1:(end-1)] * "]"
            CImGui.TextColored(color, txtStr)
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
    CImGui.Text("schedule: $(get_ids(sc._merged_subgraph))")
    CImGui.Text("roots: $([getGraphID(d) for d in sc._merged_roots])")
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

function _renderEvaluationTab1(self::GraphWindow, ::SingleFrameSingleThread, model::Model)
    _renderWorker(self, 0, model)
end

function _renderEvaluationTab1(self::GraphWindow, ::Union{SingleFrameTwoThreads, MultipleFramesSingleThread}, model::Model)
    _renderWorker(self, 1, model)
end

function _renderEvaluationTab1(self::GraphWindow, ::Union{SingleFrameMultipleThreads, MultipleFramesMultipleThreads}, model::Model)
    for idx in 1:length(getWorkers(model))
        _renderWorker(self, idx, model)
    end
end

function _renderWorker(self::GraphWindow, idx::Int, model::Model)
    CImGui.Separator()

    _ids::Vector{Int} = self._workerIDs[idx+1]
    _times::Vector{Float32} = self._workerTimes[idx+1]

    maxVal::Float32 = Float32(0.0)
    !isempty(_times) ? maxVal = maximum(_times) : nothing

    CImGui.PushStyleColor(CImGui.ImGuiCol_PlotHistogram,        (idx2basecol(self,idx)...,1.0))
    CImGui.PushStyleColor(CImGui.ImGuiCol_PlotHistogramHovered, (idx2hoveredcol(self,idx)...,1.0))
    CImGui.PlotHistogram("##$(idx)", _times, length(_times), 0, "Worker$(idx)", 0.0, maxVal, (-1.0,50.0), sizeof(Float32))
    CImGui.PopStyleColor(2)

    if CImGui.BeginTable("##WorkerTable$(idx)",3,
        CImGui.ImGuiTableFlags_Borders)

        CImGui.TableSetupColumn("Processed")
        CImGui.TableSetupColumn("Slowest time")
        CImGui.TableSetupColumn("Sum time")
        CImGui.TableHeadersRow()

        CImGui.TableNextRow()

        CImGui.TableNextColumn()
        CImGui.Text("$(length(_ids))")
        
        CImGui.TableNextColumn()
        CImGui.Text("$(maxVal)")

        CImGui.TableNextColumn()
        CImGui.Text("$(self._workerSum[idx+1])")

        CImGui.EndTable()
    end
    
    CImGui.Spacing()
    CImGui.Spacing()
    CImGui.Spacing()
end