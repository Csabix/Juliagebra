
# ? For Subject-Observers who use OpenGL.
abstract type RenderedDependentDNA  <: SubjectDNA end
abstract type RendererDNA{T<:RenderedDependentDNA} <: ObserverDNA{RenderedDependentDNA} end

# ? For dependents who may be tessellated on the GPU
abstract type ParametricDependentDNA <: RenderedDependentDNA end

# ? For Subject-Observers who use ImGui.
abstract type GuiDependentDNA <: SubjectDNA end
abstract type GuiRendererDNA{T<:GuiDependentDNA} <: ObserverDNA{GuiDependentDNA} end