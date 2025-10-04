using Juliagebra

App()

t1 = Toggle()

p1 = Point(5,5,5, [t1]) do t1
    if (isToggled(t1))
        return (1,1,1)
    end

    return (2,2,2)
end

t2 = Toggle([t1]) do t1
    if(isToggled(t1))
        return false
    end

    return true
end

p2 = Point([p1,t2]) do p1,t2
    if(isToggled(t2))
        return p1[:xyz] .* -1
    end

    return (p1[:xyz] .* -3)
end

play!()