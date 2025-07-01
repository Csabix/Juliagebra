#
#   GeometryRenderer
#

abstract type AbstractGeometryRenderer{G<:Geometry, V}
    # buffer      :: Vector{V}
    # geometries  :: Vector{InteractiveGeometry{G}}
    # dirtybit    :: Bool
end
getindex(gc::AbstractGeometryRenderer, id) = gc.data[id_to_index(gc,id)]
dirty!(gr::AbstractGeometryRenderer) ::Nothing = (gr.dirtybit=true, nothing)
render(gc::AbstractGeometryRenderer) = println("Abstract geometry draw\n",gc)

id_to_index(gc::AbstractGeometryRenderer,id) = id # Maps renderer's id read from FBO to an index in data. TODO overload thebejesus outof this


struct GeometryRenderer{G<:Geometry,V} <: AbstractGeometryRenderer{G<:Geometry,V}
    buffer      :: Vector{V}
    geometries  :: Vector{InteractiveGeometry{G}}
    dirtybit    :: Bool
end

render(gc::GeometryRenderer{<:StaticGeometries})  = println("Static geometry draw\n",gc)  # could use "data" buffer directly        TODO implement
render(gc::GeometryRenderer{<:DynamicGeometries}) = println("Dynamic geometry draw\n",gc) # must manage memory or render seperately TODO implement

# problem 1: GeometryRenderer and InteractiveGeometry cannot both contain the same geometry
#   sol 1: InteractiveGeometry could contain references.
#       but  : GeometryRenderer still needs a second buffer to snyc data to
#       problem: Where to store and InteractiveGeometry? Hot to seperate Dependent and Movable?
#   sol 2:  GeometryRenderer stores InteractiveGeometry-s and each of those store a Geometry
#       GeometryRenderer syncs buffers, InteractiveGeometry-s reference and update each other
#
# problem: GeometryRenderer needs to know when it is 'dirty'!
#   sol: Dependent must signal when they become dirty (lated can be optimized)
#
# problem: GeometryRenderer does too many things (actually, data doesn't do anything)
#       0. stores geometry in organised 'islands' (this is not an action though!)
#       1. Syncronizes storage with flat buffer
#           1.a) OpenGL ID -> update Movable state
#           1.b) When dirty, must update again
#       2. Defines render job boundaries, render batches: (vao vbo layout, shader program, framebuffer)
#   sol: Remove the last job: should return RenderJobs???
#
# problem: GeometryRenderer needs raw buffer. How do we define the layout??
#   sol: another type parameter! 
#
# problem: GeometryRenderer{Mesh} might need index buffer too
#   sol: AbstractGeometryRenderer ??


struct RenderJob
   vao  
end