using Juliagebra
using JuliaGLM
using LinearAlgebra

const width::Float64 = 0.2
#const Vec2D = GenericDependent{Vec2T{Float64}}
#const Scalar = GenericDependent{Float64}

function triangle(a,b,c,col)
    ParametricSurface(range(0.0,1.0,3),range(0.0,1.0,3),[a,b,c];color=col) do u,v,a,b,c
        if (u>=0.5 && v>=0.5)
            u = 0.5
            v = 0.5
        end
        return (1-u-v) .* a .+ u .* b .+ v .* c
    end
end

function distance(A,B)
    return ValueHolder(Float64,[A,B]) do A, B
        return norm(A - B)
    end
end

function get_direction(A,B)
    diff = A - B
    d = norm(diff)
    return Vec2T{Float64}(diff.x / d, diff.z / d)
end

rot_clockwise(v) = Vec2T{Float64}(v.y, -v.x)
rot_counter_clockwise(v) = Vec2T{Float64}(-v.y, v.x)

function curve_segment(A,B,C,D)
    sr = ValueHolder(width)
    Sphere(A,sr,color=(0.1,0.1,0.1,0.1))
    Sphere(B,sr,color=(0.1,0.1,0.1,0.1))
    Sphere(C,sr,color=(0.1,0.1,0.1,0.1))
    Sphere(D,sr,color=(0.1,0.1,0.1,0.1))
    distance_X = distance(A,B)
    distance_Y = distance(C,B)
    distance_Z = distance(C,D)

    AB_dir = ValueHolder(get_direction,Vec2T{Float64},[A, B])
    CB_dir = ValueHolder(get_direction,Vec2T{Float64},[C, B])
    DC_dir = ValueHolder(get_direction,Vec2T{Float64},[D, C])

    AB_dir_r = ValueHolder(rot_clockwise, Vec2T{Float64}, [AB_dir])
    CB_dir_r = ValueHolder(rot_counter_clockwise, Vec2T{Float64}, [CB_dir])
    DC_dir_r = ValueHolder(rot_counter_clockwise, Vec2T{Float64}, [DC_dir])

    inner_offset_ABC = ValueHolder(Vec2T{Float64},[AB_dir, AB_dir_r, CB_dir, CB_dir_r]) do AB_dir, AB_dir_r, CB_dir, CB_dir_r
        if dot(AB_dir,CB_dir) <= -0.9999
            return CB_dir_r
        else
            return (Vec2T{Float64}(1.0,1.0)./dot(AB_dir_r,CB_dir)) .* CB_dir .+ (Vec2T{Float64}(1.0,1.0)./dot(CB_dir_r,AB_dir)) .* AB_dir
        end
    end

    inner_offset_BCD = ValueHolder(Vec2T{Float64},[CB_dir, CB_dir_r, DC_dir, DC_dir_r]) do CB_dir, CB_dir_r, DC_dir, DC_dir_r
        if dot(-CB_dir, DC_dir) <= -0.9999
            return CB_dir_r
        else
            return (Vec2T{Float64}(1.0,1.0) ./ dot(CB_dir_r, DC_dir)) .* DC_dir .+ (Vec2T{Float64}(1.0,1.0) ./ dot(DC_dir_r, -CB_dir)) .* -CB_dir
        end
    end

    function draw_vector(origin,dir;color="c",style="->",width=5.0f0)
        offset = Point([origin,dir],size=0) do o,d
            d3 = Vec3D(d[1],0.0,d[2])
            return o + d3
        end
        Segment(origin, offset;color=color,style=style,width=width)
    end
    draw_vector(B,inner_offset_ABC;color="y")
    draw_vector(C,inner_offset_BCD;color="m")

    begin_inner_offset = ValueHolder(Vec2T{Float64},[CB_dir, CB_dir_r, AB_dir, inner_offset_ABC, distance_X, distance_Y]) do CB_dir, CB_dir_r, AB_dir, inner_offset_ABC, distance_X, distance_Y
        if dot(AB_dir,CB_dir) <= 0.00006
            return inner_offset_ABC
        else
            AB_l = distance_X ./ width;
            CB_l = distance_Y ./ width;
            ab = abs(dot(inner_offset_ABC,AB_dir));
            cb = abs(dot(inner_offset_ABC,CB_dir));
            if ab < AB_l && cb < CB_l
                if dot(inner_offset_ABC, AB_dir + CB_dir) < 0.0
                    return -CB_dir + CB_dir_r
                else
                    return inner_offset_ABC
                end
            else
                return -CB_dir + CB_dir_r
            end
        end
    end

    begin_outer_offset = ValueHolder(Vec2T{Float64},[AB_dir, CB_dir, CB_dir_r, inner_offset_ABC, distance_X, distance_Y]) do AB_dir, CB_dir, CB_dir_r, inner_offset_ABC, dX, dY
        # Obtuse Case
        if dot(AB_dir, CB_dir) <= 0.00006
            return -inner_offset_ABC
        else
            # Acute Case
            AB_l, CB_l = dX ./ width, dY ./ width
            ab = abs(dot(inner_offset_ABC, AB_dir))
            cb = abs(dot(inner_offset_ABC, CB_dir))

            if ab < AB_l && cb < CB_l
                if (dot(inner_offset_ABC, AB_dir + CB_dir) < 0.0)
                    return -inner_offset_ABC;
                else
                    return -CB_dir - CB_dir_r;
                end
            else
                return -CB_dir - CB_dir_r
            end
        end
    end

    end_inner_offset = ValueHolder(Vec2T{Float64},[CB_dir, CB_dir_r, DC_dir, inner_offset_BCD, distance_Y, distance_Z]) do CB_dir, CB_dir_r, DC_dir, inner_offset_BCD, dY, dZ
        # Obtuse Case
        if dot(-CB_dir, DC_dir) <= 0.00006
            return inner_offset_BCD
        else
            # Acute Case
            BC_l, DC_l = dY ./ width, dZ ./ width
            bc = abs(dot(inner_offset_BCD, -CB_dir))
            dc = abs(dot(inner_offset_BCD, DC_dir))
            if bc < BC_l && dc < DC_l
                if dot(inner_offset_BCD, -CB_dir + DC_dir) < 0.0
                    return CB_dir + CB_dir_r
                else
                    return inner_offset_BCD
                end
            else
                return CB_dir + CB_dir_r
            end
        end
    end

    end_outer_offset = ValueHolder(Vec2T{Float64},[CB_dir, CB_dir_r, DC_dir, inner_offset_BCD, distance_Y, distance_Z]) do CB_dir, CB_dir_r, DC_dir, inner_offset_BCD, dY, dZ
        if dot(-CB_dir, DC_dir) <= 0.00006
            return -inner_offset_BCD
        else
            BC_l, DC_l = dY ./ width, dZ ./ width
            bc = abs(dot(inner_offset_BCD, -CB_dir))
            dc = abs(dot(inner_offset_BCD, DC_dir))

            if bc < BC_l && dc < DC_l
                return dot(inner_offset_BCD, -CB_dir + DC_dir) < 0.0 ? -inner_offset_BCD : (CB_dir - CB_dir_r)
            else
                return CB_dir - CB_dir_r
            end
        end
    end

    end_outer_third_offset = ValueHolder(Vec2T{Float64},[CB_dir, DC_dir, DC_dir_r, inner_offset_BCD, distance_Y, distance_Z]) do CB_dir, DC_dir, DC_dir_r, inner_offset_BCD, dY, dZ
        # Only exists in specific Acute case
        if dot(-CB_dir, DC_dir) > 0.00006
            BC_l, DC_l = dY ./ width, dZ ./ width
            bc = abs(dot(inner_offset_BCD, -CB_dir))
            dc = abs(dot(inner_offset_BCD, DC_dir))

            if bc < BC_l && dc < DC_l
                return dot(inner_offset_BCD, -CB_dir + DC_dir) < 0.0 ? (-DC_dir + DC_dir_r) : (-DC_dir - DC_dir_r)
            end
        end
        return Vec2T{Float64}(Inf, Inf)
    end

    r1 = Point([B,begin_inner_offset]) do B, begin_inner_offset
        begin_inner_offset = begin_inner_offset .* width
        return Vec3T{Float64}(B.x + begin_inner_offset.x, 0, B.z + begin_inner_offset.y)
    end
    r2 = Point([B, begin_outer_offset]) do B, begin_outer_offset
        begin_outer_offset = begin_outer_offset .* width
        return Vec3T{Float64}(B.x + begin_outer_offset.x, 0, B.z + begin_outer_offset.y)
    end
    r3 = Point([C, end_inner_offset]) do C, end_inner_offset
        end_inner_offset = end_inner_offset .* width
        return Vec3T{Float64}(C.x + end_inner_offset.x, 0, C.z + end_inner_offset.y)
    end
    r4 = Point([C, end_outer_offset]) do C, end_outer_offset
        end_outer_offset = end_outer_offset .* width
        return Vec3T{Float64}(C.x + end_outer_offset.x, 0, C.z + end_outer_offset.y)
    end
    r5 = Point([C, end_outer_third_offset]) do C, end_outer_third_offset
        end_outer_third_offset = end_outer_third_offset .* width
        return Vec3T{Float64}(C.x + end_outer_third_offset.x, 0, C.z + end_outer_third_offset.y)
    end

    triangle(r1,r2,r3,(1,0,0))
    triangle(r3,r2,r4,(0,1,0))
    triangle(r3,r4,r5,(0,0,1))
end

A = Point(0, 0, 0)
B = Point(0, 0, 1)
C = Point(1, 0, 2)
D = Point(2, 0, 2)
E = Point(3, 0, 2)
F = Point(4, 0, 2)

curve_segment(A,B,C,D)
curve_segment(B,C,D,E)
curve_segment(C,D,E,F)

Segment(A,B,style=ARROW)
Segment(B,C,style=ARROW)
Segment(C,D,style=ARROW)
Segment(D,E,style=ARROW)

Juliagebra.Wait()