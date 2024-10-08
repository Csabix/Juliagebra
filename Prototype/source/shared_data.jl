#=
  #####                                           ######
 #     #  #    #    ##    #####   ######  #####   #     #    ##    #####    ##
 #        #    #   #  #   #    #  #       #    #  #     #   #  #     #     #  #
  #####   ######  #    #  #    #  #####   #    #  #     #  #    #    #    #    #
       #  #    #  ######  #####   #       #    #  #     #  ######    #    ######
 #     #  #    #  #    #  #   #   #       #    #  #     #  #    #    #    #    #
  #####   #    #  #    #  #    #  ######  #####   ######   #    #    #    #    #

=#

mutable struct SharedData

    name::String
    width::Int
    height::Int
    gameOver::Bool

    function SharedData(name::String,width::Int,height::Int)
        new(name,width,height,false)
    end
end