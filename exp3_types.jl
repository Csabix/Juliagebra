abstract type ADNA end
abstract type BDNA end
abstract type AnBDNA end

struct A
    name::String
end

struct B
    num::Int
end

ADNAPool = Union{ADNA,AnBDNA}
BDNAPool = Union{BDNA,AnBDNA}

_A_(self::ADNAPool)::A = error("A needed!")
_B_(self::BDNAPool)::B = error("B needed!")

function checkA(self::ADNAPool)
    println(_A_(self).name)
end

function checkB(self::T) where T<:BDNAPool
    println(_B_(self).num)
end

struct AOnly <: ADNA
    a::A
end

_A_(self::AOnly) = return self.a

struct BOnly <: BDNA
    b::B
end

_B_(self::BOnly) = return self.b

struct AnB <: AnBDNA
    a::A
    b::B
end

_A_(self::AnBDNA) = return self.a
_B_(self::AnBDNA) = return self.b

aOnly = AOnly(A("alma"))
bOnly = BOnly(B(55))
aNB   = AnB(A("cseresznye"),B(99))

checkA(aOnly)
checkB(bOnly)
checkA(aNB)
checkB(aNB)

# ! checkA(bOnly)
# ! checkB(aOnly)
