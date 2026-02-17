
# ? ---------------------------------
# ! Tetrahedra
# ? ---------------------------------

function Tetrahedra(a::PointPlan,b::PointPlan,c::PointPlan,d::PointPlan;transparent=false,color=(0.1,0.8,0.2))

    Triangle(a,c,b;transparent=transparent,color=color)
    Triangle(a,b,d;transparent=transparent,color=color)
    Triangle(a,d,c;transparent=transparent,color=color)
    Triangle(b,c,d;transparent=transparent,color=color)

end



export Tetrahedra