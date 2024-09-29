include("Prototype/juliagebra.jl")
using .JuliAgebra

app = Manager{JuiliAgebraLogicsController,OpenGLGLFWController}()
run!(app)
