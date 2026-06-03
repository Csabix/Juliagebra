
abstract type DependentDNA end 

abstract type ValueHolderDNA{T} <: DependentDNA end
abstract type SourceValueHolderDNA{T} <: ValueHolderDNA{T} end

abstract type SubjectDNA <: DependentDNA end
abstract type ObserverBuilderDNA end
abstract type ObserverDNA{T<:SubjectDNA} end

abstract type RenderedDependentDNA  <: SubjectDNA end
abstract type RendererDNA{T<:RenderedDependentDNA} <: ObserverDNA{RenderedDependentDNA} end

abstract type GuiDependentDNA <: SubjectDNA end
abstract type GuiRendererDNA{T<:GuiDependentDNA} <: ObserverDNA{GuiDependentDNA} end

abstract type AppDNA end
abstract type ImGuiDNA end

abstract type WidgetDNA end
abstract type OpenGLWidgetDNA <: WidgetDNA end
abstract type ImGuiWidgetDNA <: WidgetDNA end
abstract type WindowDNA <: ImGuiWidgetDNA end

abstract type Primitive end
abstract type AABBPrimitive <: Primitive end
abstract type AABBPrimitive2D <: AABBPrimitive end
abstract type AABBPrimitive3D <: AABBPrimitive end

abstract type PrimitivesOf{T<:Primitive} end

const IntersectT= Union{Vec3D,Primitive}