
# ! Mod = Moddable = can move it's vertexes.
# ! Lim = Limited = Fix number of starting points.

# TODO: rename theese structs to something better.

mutable struct ModLimBody <: AlgebraObject
    _vertexes::AbstractArray{Vec3,1}
    
    function ModLimBody(vertexes)
        new(vertexes)
    end

end

mutable struct ModLimBodyPlan <:RenderPlan
    _vertexes::Vector{Vec3}

end

mutable struct ModLimRenEmp <:RenderEmployees
    _assets::ModLimBody
    _gpuBuffer::Vector{Vec3}

    function ModLimRenEmp(asset::ModLimBody,vertexes::Vector{Vec3})
        new(asset,vertexes)
    end

end

function recruit!(plan::ModLimBodyPlan)::ModLimRenEmp
    
    vertexes = deepcopy(plan._vertexes)
    println(vertexes)
    asset = ModLimBody(view(vertexes, : ))
    employee = ModLimRenEmp(asset,vertexes)
    return employee

end

export ModLimBodyPlan