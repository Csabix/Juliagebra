abstract type PlanDNA end
abstract type RenderedPlanDNA <: PlanDNA end
abstract type QueueLockDNA end
abstract type AlgebraDNA end 
abstract type RenderedAlgebraDNA  <: AlgebraDNA end
abstract type RendererDNA{T<:RenderedAlgebraDNA} <: QueueLockDNA end

QueueLockPool = Union{RenderedAlgebraDNA,QueueLockDNA}