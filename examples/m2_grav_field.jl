using Juliagebra

Juliagebra.Window() do 
    cursor = Point(0,0,5)

    function wave(xf,yf,zf,cap,xc,yc,zc)
        distance = sqrt((xc - xf)^2 + (yc - yf)^2)/ cap * 0.2

        if distance > 1
            distance = 1
        end

        z = zc + (zf - zc) * distance
        return (xf,yf,z-0.1)
    end

    #for x in -10:10
    #    for y in -10:10
    #        cap = 3.0
    #        xf = x * cap
    #        yf = y * cap
    #        Point([cursor]) do cur
    #            return wave(xf,yf,0.0,cap,cur.x,cur.y,cur.z)
    #        end
    #    end
    #end

    StaticPointCloud([cursor]) do cur
        positions = Tuple[]
        for x in -10:10
            for y in -10:10
                cap = 3.0
                xf = x * cap
                yf = y * cap
                push!(positions,wave(xf,yf,0.0,cap,cur.x,cur.y,cur.z))
            end
        end
        return positions
    end

    s = Slider(0.0,10.0)
    PointCloud([s]) do s
        return [(0.0,0.0,i) for i in 0:s]
    end

end


#Juliagebra.Wait()