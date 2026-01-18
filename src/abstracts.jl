abstract type PlanDNA end
abstract type ValueHolderPlanDNA{T} <: PlanDNA end
abstract type SourceValueHolderPlanDNA{T} <: ValueHolderPlanDNA{T} end
abstract type ObservedPlanDNA <: PlanDNA end
abstract type RenderedPlanDNA <: ObservedPlanDNA end
abstract type GuiPlanDNA <: ObservedPlanDNA end
abstract type QueueLockDNA end

abstract type DependentDNA end 
abstract type DependentGraphDNA end

abstract type ValueHolderDNA{T} <: DependentDNA end
abstract type SourceValueHolderDNA{T} <: ValueHolderDNA{T} end

abstract type ObservedDNA <: DependentDNA end
abstract type ObserverBuilderDNA end
abstract type ObserverDNA{T<:ObservedDNA} end

abstract type RenderedDependentDNA  <: ObservedDNA end
abstract type RendererDNA{T<:RenderedDependentDNA} <: ObserverDNA{RenderedDependentDNA} end

abstract type GuiDependentDNA <: ObservedDNA end
abstract type GuiRendererDNA{T<:GuiDependentDNA} <: ObserverDNA{GuiDependentDNA} end

abstract type CollectedDNA <:QueueLockDNA end
abstract type CollectorDNA{T} end
abstract type CollectedCollectorDNA{T} end

abstract type AppDNA end

abstract type WidgetDNA end
abstract type OpenGLWidgetDNA <: WidgetDNA end
abstract type ImGuiWidgetDNA <: WidgetDNA end
abstract type WindowDNA <: ImGuiWidgetDNA end

abstract type Primitive end
abstract type AABBPrimitive <: Primitive end

abstract type PrimitivesOf end
abstract type AABBPrimitivesOf <: PrimitivesOf end
abstract type PTrianglesOf <: AABBPrimitivesOf end
abstract type PSegmentsOf <: AABBPrimitivesOf end

const IntersectT= Union{Vec3D,Primitive}

const QueueLockPool = Union{RenderedDependentDNA,QueueLockDNA,CollectedDNA,CollectedCollectorDNA}

const DependentsT = Vector{T} where T <: PlanDNA