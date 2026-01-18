
# ? ---------------------------------
# ! ValueHolderPlan{T}
# ? ---------------------------------

mutable struct ValueHolderPlan{T} <: PlanDNA
    _plan::Plan

    function ValueHolderPlan{T}(callback::Function,plans::Vector{<:PlanDNA}) where T
        plan = Plan(callback,plans)
        new(plan)
    end
end

function _ValueHolderPlan_(self::ValueHolderPlanDNA{T})::ValueHolderPlan{T} where T
    error("Missing func!") 
end

_Plan_(self::ValueHolderPlanDNA)::Plan = return _ValueHolderPlan_(self)._plan

# ? ---------------------------------
# ! ValueHolder{T}
# ? ---------------------------------

mutable struct ValueHolder{T} <: DependentDNA
    _dependent::Dependent

    function ValueHolder{T}(plan::ValueHolderPlanDNA{T}) where T
        dependent = Dependent(plan)
        new(dependent)
    end
end

function _ValueHolder_(self::ValueHolderDNA{T})::ValueHolder{T} where T
    error("Missing func!")
end
_Dependent_(self::ValueHolderDNA)::Dependent = _ValueHolder_(self)._dependent


function getField(self::ValueHolderDNA{T})::T where T
    error("Missing func!")
end

function evalCallbackDpEntry(self::ValueHolderDNA{T})::T where T
    return getField(self)
end
