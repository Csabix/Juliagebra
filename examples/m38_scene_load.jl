using Juliagebra

App()

directory = @__DIR__

FILE = directory * "\\scenes\\scene_1.obj"

println(FILE)

load_scene(FILE)

play!()