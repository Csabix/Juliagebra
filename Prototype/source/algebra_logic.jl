#the controller must have open ends, for the graphics and windowing

#=
    #                                                     #
   # #    #        ####   ######  #####   #####     ##    #         ####    ####   #   ####
  #   #   #       #    #  #       #    #  #    #   #  #   #        #    #  #    #  #  #    #
 #     #  #       #       #####   #####   #    #  #    #  #        #    #  #       #  #
 #######  #       #  ###  #       #    #  #####   ######  #        #    #  #  ###  #  #
 #     #  #       #    #  #       #    #  #   #   #    #  #        #    #  #    #  #  #    #
 #     #  ######   ####   ######  #####   #    #  #    #  #######   ####    ####   #   ####

=#

#Array{T,1} = Vector{T}

mutable struct AlgebraLogic
    _shrd::SharedData
    _algObjs::Vector{AlgebraObject}

    function AlgebraLogic(shrd::SharedData)
        new(shrd,Vector{AlgebraObject}())
    end

end

function init!(_loc::AlgebraLogic)

end

function update!(_loc::AlgebraLogic)

end

function destroy!(_loc::AlgebraLogic)

end

