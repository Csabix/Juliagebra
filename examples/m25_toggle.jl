using Juliagebra

# TODO: Continue this.
t1 = Toggle()

p1 = Point([t1]) do t1
    if (t1)
        return (1,1,1)
    end

    return (2,2,2)
end

t2 = Toggle([t1]; label="t2") do t1
    if(t1)
        return false
    end

    return true
end

p2 = Point([p1,t2]) do p1,t2
    if(t2)
        return p1 .* -1
    end

    return (p1 .* -3)
end

Juliagebra.Wait()