#the controller must have open ends, for the graphics and windowing


mutable struct JuiliAgebraLogicsController<:ALogicsController
    _shrd::SharedData
end

function init!(_loc::JuiliAgebraLogicsController)

end

function update!(_loc::JuiliAgebraLogicsController)

end

function destroy!(_loc::JuiliAgebraLogicsController)

end

export JuiliAgebraLogicsController