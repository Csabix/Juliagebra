using Clang.Generators
using assimp_jll

cd(@__DIR__)

include_dir = normpath(assimp_jll.artifact_dir,"include","assimp")
clang_dir = joinpath(include_dir, "clang-c")

options = load_options(joinpath(@__DIR__, "generator.toml"))

args = get_default_args()
push!(args, "-I$include_dir")

headers = [joinpath(include_dir, header) for header in ["cimport.h","scene.h","postprocess.h","config.h"]]

ctx = create_context(headers, args, options)

build!(ctx)