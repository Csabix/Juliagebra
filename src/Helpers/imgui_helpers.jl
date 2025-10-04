
function slider1(self::T,text::String,min::AbstractFloat,max::AbstractFloat)::Union{T,Nothing} where T
    self_ref = Ref(self)
    if (CImGui.SliderFloat(text,self_ref,min,max))
        return self_ref[]
    end

    return nothing
end

function slider3(self::Vec3T,text::String,min::AbstractFloat,max::AbstractFloat)::Vec3T
    self_ref = Ref(self)
    CImGui.SliderFloat3(text,self_ref,min,max)
    return self_ref[]
end

function slider1i(self,text::String,min::Integer,max::Integer)
    self_ref = Ref(self)
    CImGui.SliderInt(text,self_ref,min,max)
    return self_ref[]
end

function getButtonSize(text::String)
    size = CImGui.CalcTextSize(text)
    padding = CImGui.GetStyle().FramePadding

    size_x = size.x
    size_y = size.y
        
    padding_x = unsafe_load(padding.x)
    padding_y = unsafe_load(padding.y)

    size_x += padding_x * 2
    size_y += padding_y * 2

    return (size_x,size_y)
end

# ? Could microoptimize this by not creating buffers everytime if necessary
function txtbox(name::String,text::String,buf_size=1024)::Union{String,Nothing}
    
    if (length(text)>= buf_size)
        text = text[1:buf_size-1]
    end
    
    buf = Vector{UInt8}(undef,buf_size)
    fill!(buf,0)

    textAsUint8s = codeunits(text)
    copyto!(buf,textAsUint8s)
    
    if (CImGui.InputTextMultiline(name,buf,length(buf)))
        return unsafe_string(pointer(buf))
    end

    return nothing
end