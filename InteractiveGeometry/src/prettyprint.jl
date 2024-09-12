
using PrettyPrint

PrettyPrint.pp_impl(io,v::Vec{N,T} where {N,T<:AbstractFloat},it::Int) = begin printstyled(io,Float64[v...];bold=true,color=6); return it end
PrettyPrint.pp_impl(io,v::Vec{N,T} where {N,T<:Integer      },it::Int) = begin printstyled(io,    Int[v...];bold=true,color=2); return it end

function PrettyPrint.pp_impl(io,x::CommonProperties,it::Int)
    printstyled(io,"(";color=3);
    for v in fieldnames(typeof(x))
        printstyled(io,v,"=";italic=true,color=0)
        pprint(io,getfield(x,v),it); print(io,", ")
    end
    printstyled(io,")";color=3);
    return it
end

function PrettyPrint.pp_impl(io,x::InteractiveGeometry, it::Int)
    col = (typeof(x) <: Dependent ? 105 : 202);
    ind = " "^it;
    printstyled(io,"$(typeof(x).name.name){";color=col);
    printstyled(io,"$(typeof(x).parameters[1].name.name)"; bold=true, color=3);
    printstyled(io,"}","(";color=col);
    print(io,"id=$(id(x)), label=\"$(label(x))\"")
    if it < 4
        print(io,"\n")
        for v in fieldnames(typeof(x))
            printstyled(io,ind*"  ",v," = ";italic=true,bold=true,color=0)
            pprint(io,getfield(x,v),it+2); print(io,",\n")
        end
        print(io,ind)
    end
    printstyled(io,")";color=col);
    return it
end

function PrettyPrint.pp_impl(io,x::Function,it::Int)
    printstyled(io, join(split("$(code_lowered(x)[1])",'\n'),"\n  "*" "^it) ;color=5)
    return it
end