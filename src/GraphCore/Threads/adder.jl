
# ? ---------------------------------
# ! Adder
# ? ---------------------------------

@kwdef mutable struct Adder
    _in::Channel{DependentDNA} = Channel{DependentDNA}(100)
end