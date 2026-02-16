

function SameDistancePPlane(p1::Vec3D,p2::Vec3D)::PPlane
    plane_n = p2 - p1
    plane_c = ((p2 - p1) / 2.0) + p1
    return PPlane(plane_c,plane_n)
end

function FourPointOnPSphere(p1::Vec3D,p2::Vec3D,p3::Vec3D,p4::Vec3D)::Union{PSphere,Nothing}
    plane_12 = SameDistancePPlane(p1,p2)
    plane_34 = SameDistancePPlane(p3,p4)

    line_12_34 = PrimitiveToPrimitiveIntersection(plane_12,plane_34)
    if (isnothing(line_12_34))
        return nothing
    end

    plane_23 = SameDistancePPlane(p2,p3)

    c = PrimitiveToPrimitiveIntersection(line_12_34,plane_23)
    if (isnothing(c))
        return nothing
    end

    r = norm(p1 - c)

    return PSphere(c,r)
end