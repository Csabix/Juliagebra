# forward methods
#for method in (:double, :shout)
#    @eval $method(wif::WantsInterestingField) = $method(wif.interesting)
#end


@doc """
    connect macro connects a list of types functions to a type member. 
"""
macro connect(type, type_member, methods...)
    connections = Expr[]
    for method in methods
        push!(connections, :($method(o::$type) = $method(o.$type_member)))
    end

    return quote
       $(connections...)
    end
end

export @connect