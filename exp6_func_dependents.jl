function alma(a,b,c=a*5)
    println("$(a) - $(b) - $(c)")
end

function barack(; a,b,c=a*5)
    println("$(a) - $(b) - $(c)")
end

function cseresznye(aa,bb; a=aa,b=bb,c=a*5)
    println("$(a) - $(b) - $(c)")
end

alma(1,2)

alma(1,2,3)

barack(a=5,b=2,c=15)

barack(a=5,b=2)

cseresznye(5,6)

cseresznye(5,6,c=9)




