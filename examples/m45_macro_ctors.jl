using Juliagebra
using JuliaGLM

App()

p1 = Point(0,0,0)

p2 = @Point () -> (p1["x"], p1["y"], p1["z"] - 1)

test_global = 1

let
    test_local = 2

    @Point() do
        global test_global
        println(test_global)
        println(test_local)

        (p1["x"], p1["y"], p2["z"] + 2)
    end
end

play!()
