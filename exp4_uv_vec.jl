function at(self,u,v,last,width)
    return self[last + u + (v-1) * width]
end

a = [1,1,1,1,
     2,2,2,2,
     3,3,3,3,
     
     4,4,4,
     5,5,5,
     
     6,6,6,6,6,
     7,7,7,7,7,
     
     8,8,
     
     9,9,9,
     
     66,66,66,
     77,77,77,
     88,88,88]

w1 = 4
h1 = 3
s1 = w1*h1     

w2 = 3
h2 = 2
s2 = w2*h2

w3 = 5
h3 = 2
s3 = w3*h3

w4 = 2
h4 = 1
s4 = w4*h4

w5 = 3
h5 = 1
s5 = w5*h5

w6 = 3
h6 = 3
s6 = w6*h6

function iterateVec(self,last,width,height)
    println("$(last) - $(width) - $(height)")
    for v in 1:height
        for u in 1:width
            println("u:($(u)), v:($(v)) = $(at(self,u,v,last,width))")
        end
    end
    println()
end

println(a)
println()
iterateVec(a,0,w1,h1)
iterateVec(a,s1,w2,h2)
iterateVec(a,s1+s2,w3,h3)
iterateVec(a,s1+s2+s3,w4,h4)
iterateVec(a,s1+s2+s3+s4,w5,h5)
iterateVec(a,s1+s2+s3+s4+s5,w6,h6)
