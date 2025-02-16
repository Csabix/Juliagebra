abstract type PlanDNA                                       end
abstract type QueueLockDNA                                  end
abstract type AlgebraDNA  <: QueueLockDNA                   end
abstract type RendererDNA{T<:AlgebraDNA} <: QueueLockDNA    end
