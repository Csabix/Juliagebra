using Test

const RUN_MODEL_TESTS = true
const RUN_MACRO_TESTS = true

RUN_MACRO_TESTS ? include("model_tests.jl") : nothing
RUN_MACRO_TESTS ? include("macro_tests.jl") : nothing
