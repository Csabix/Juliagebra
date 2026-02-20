using Juliagebra
Juliagebra.Init() do
    cursor = Point(0,0,5)

    function wave(xf,yf,zf,cap,xc,yc,zc)
        distance = sqrt((xc - xf)^2 + (yc - yf)^2)/ cap * 0.2

        if distance > 1
            distance = 1
        end

        z = zc + (zf - zc) * distance
        return (xf,yf,z)
    end

    for x in -10:10
        for y in -10:10
            cap = 3.0
            xf = x * cap
            yf = y * cap
            Point([cursor]) do cur
                return wave(xf,yf,0.0,cap,cur.x,cur.y,cur.z)
            end
        end
    end
end


