abstract type PlanDNA end
abstract type RenderedPlanDNA <: PlanDNA end
abstract type QueueLockDNA end
abstract type DependentDNA end 
abstract type RenderedDependentDNA  <: DependentDNA end
abstract type RendererDNA{T<:RenderedDependentDNA} <: QueueLockDNA end

QueueLockPool = Union{RenderedDependentDNA,QueueLockDNA}