abstract type PlanDNA end
abstract type RenderedPlanDNA <: PlanDNA end
abstract type QueueLockDNA end
abstract type DependentDNA end 

abstract type CollectedDNA <:QueueLockDNA end
abstract type CollectorDNA{T} end
abstract type CollectedCollectorDNA{T} end

abstract type RenderedDependentDNA  <: DependentDNA end
abstract type RendererDNA{T<:RenderedDependentDNA} <: QueueLockDNA end

const QueueLockPool = Union{RenderedDependentDNA,QueueLockDNA,CollectedDNA,CollectedCollectorDNA}