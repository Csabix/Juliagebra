
# ? ---------------------------------
# ! WorkerInfo
# ? ---------------------------------

@kwdef mutable struct WorkerInfo <: WindowDNA
    _window::Window=Window()
end

_Window_(self::WorkerInfo)::Window = return self._window
getWindowName(self::WorkerInfo)::String = return "WorkerInfo"

function renderContent(::WorkerInfo, app::AppDNA)    
    CImGui.Text("Last frame worker Data:")
    # TODO: Continue Here

end