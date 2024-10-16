# * job of the renderboss is to manage all renderemployees.
# * all renderemployess have assets, which they manage and care for.
# * the boss builds an asset for the employee, from a plan, and then tells the employee to manage and care for it.

abstract type RenderEmployees end

# ! ReEm = RenderEmployees


# TODO change name to something better.
abstract type RenderPlan end

mutable struct RenderBoss
    _employees::Vector{RenderEmployees}

    function RenderBoss()
        new(Vector{RenderEmployees}())
    end
end

function submit!(boss::RenderBoss,plan::RenderPlan)
    push!(boss._employees,recruit!(plan))
end