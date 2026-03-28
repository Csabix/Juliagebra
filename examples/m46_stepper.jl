
using Juliagebra

s = Stepper(-1.0)

p = Point([s]) do s 
    return (s,0,0)
end

vh = ValueHolder(Float64,[p]) do p
    return p.z    
end

Stepper(vh; label="Stepper with ValueHolder")

Juliagebra.Wait()