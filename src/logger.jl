using DataStructures

# Not using enums becuase I can't use them to index, or atleast they're jank
const LOG::UInt = 1
const INFO::UInt = 2
const WARN::UInt = 3
const ERR::UInt = 4

# Ascii only, for now
struct Cmsg
    type::UInt
    text::String
end

global _messages::CircularBuffer{Cmsg} = CircularBuffer{Cmsg}(100)
global _filters::Array{Bool, 1} = [true,true,true,true]

# I would avoid the string creation if possible, thats why I recommend using the macros
macro log(msg, type=:(LOG))
    if isa(msg, Expr) || isa(msg, Symbol)
        msg = esc(msg)
    end
    return :(
        if (_filters[$type])
            push!(_messages, Cmsg($type,$msg))
        end
    )
end

function log(msg,type=LOG)
    if _filters[type]
        push!(_messages, msg)
    end
    return nothing
end

function clear_logs()
    empty!(_messages)
    return nothing
end