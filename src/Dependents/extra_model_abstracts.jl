
# ? For Subject-Observers who use OpenGL.
abstract type RenderedDependentDNA  <: SubjectDNA end
abstract type RendererDNA{T<:RenderedDependentDNA} <: ObserverDNA{RenderedDependentDNA} end

# ? For Subject-Observers who use ImGui.
abstract type GuiDependentDNA <: SubjectDNA end
abstract type GuiRendererDNA{T<:GuiDependentDNA} <: ObserverDNA{GuiDependentDNA} end