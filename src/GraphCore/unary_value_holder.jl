
# ? ---------------------------------
# ! UnaryValueHolderPlan{T}
# ? ---------------------------------

mutable struct UnaryValueHolderPlan{T} <: SourceValueHolderPlanDNA{T}
    _plan::SourceValueHolderPlan{T}
    _hasChild::Bool

    function UnaryValueHolderPlan{T}(value::T) where T
        plan = SourceValueHolderPlan{T}(value)
        hasChild = false
        new(plan,hasChild)
    end
end

# TODO: When doing multi-threaded construction, shut down the window as well!
iWillDependOnYou(i::Plan,you::UnaryValueHolderPlan) = (you._hasChild) ? error("UnaryValueHolder can only have 1 child!") : (you._hasChild = true)

function _SourceValueHolderPlan_(self::UnaryValueHolderPlan{T})::SourceValueHolderPlan{T} where T
    return self._plan
end

# ? ---------------------------------
# ! UnaryValueHolderDependent{T}
# ? ---------------------------------

mutable struct UnaryValueHolderDependent{T} <: SourceValueHolderDNA{T}
    _dependent::SourceValueHolderDependent{T}

    function UnaryValueHolderDependent{T}(plan::UnaryValueHolderPlan{T}) where T
        dependent = SourceValueHolderDependent{T}(plan)
        new(dependent)
    end
end

function _SourceValueHolder_(self::UnaryValueHolderDependent{T})::SourceValueHolderDependent{T} where T
    return self._dependent
end

function Plan2Dependent(plan::UnaryValueHolderPlan{T})::UnaryValueHolderDependent{T} where T
    return UnaryValueHolderDependent{T}(plan)
end

# ? ---------------------------------
# ! UnaryValueHolder(T)
# ? ---------------------------------

function _UnaryValueHolder(;
        _app::AppDNA = implicitApp,
        _value::T
    ) where T

    plan = UnaryValueHolderPlan{T}(_value)
    submit!(_app,plan)
    return plan
end

function UnaryValueHolder(generateUnaryChild::Function,value::T) where T
    
    unary = _UnaryValueHolder(_value = value)
    plan = generateUnaryChild(unary)

    # TODO: When doing multi-threaded construction, shut down the window as well!
    (!unary._hasChild) ? error("Unary didn't get a child!") : nothing

    return plan
end

ValueHolder(generateUnaryChild::Function,value) = UnaryValueHolder(generateUnaryChild,value)

export UnaryValueHolder
