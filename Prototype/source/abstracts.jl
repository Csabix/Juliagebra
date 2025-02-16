abstract type €Plan                     end
abstract type €QueueLock                end
abstract type €Algebra  <: €QueueLock   end
abstract type €Renderer{T<:€Algebra} <: €QueueLock   end
