using Clang.Generators
using assimp_jll

cd(@__DIR__)

base_include_dir = normpath(assimp_jll.artifact_dir, "include")
assimp_header_dir = joinpath(base_include_dir, "assimp")

target_path = normpath(joinpath(@__DIR__, "..", "src", "Generated", "LibAssimp.jl"))

options = load_options(joinpath(@__DIR__, "generator.toml"))
options["general"]["output_file_path"] = target_path

args = get_default_args()
push!(args, "-I$base_include_dir")

headers = [joinpath(assimp_header_dir, h) for h in ["cfileio.h", "cimport.h", "scene.h", "postprocess.h", "config.h"]]

ctx = create_context(headers, args, options)
build!(ctx)