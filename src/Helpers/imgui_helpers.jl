
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
function color_edit3(color::UInt32, label::String)::Union{UInt32,Nothing}
    c4 = unpack_color(color)
    col = @MVector[Float32(c4[1]), Float32(c4[2]), Float32(c4[3])]
    flags = CImGui.ImGuiColorEditFlags_NoInputs |
            CImGui.ImGuiColorEditFlags_NoLabel
    if CImGui.ColorEdit3(label, col, flags)
        return get_color((col[1],col[2],col[3]))
    end
    return nothing
end

function color_edit4(color::UInt32, label::String)::Union{UInt32,Nothing}
    c4 = unpack_color(color)
    col = @MVector[Float32(c4[1]), Float32(c4[2]), Float32(c4[3]), Float32(c4[4])]
    flags = CImGui.ImGuiColorEditFlags_NoInputs |
        CImGui.ImGuiColorEditFlags_AlphaBar     |
        CImGui.ImGuiColorEditFlags_NoLabel
    if CImGui.ColorEdit4(label, col, flags)
        return get_color((col[1], col[2], col[3], col[4]))
    end
    return nothing
end

function txtbox(name::String,text::String,buf_size=1024,size=CImGui.ImVec2(CImGui.GetContentRegionAvail().x,100))::Union{String,Nothing}
    result::Union{String,Nothing} = nothing
    buf = Vector{UInt8}(undef,buf_size)
    units = codeunits(text)
    
    # Not ideal because it can cut a character in half
    copy_end = min(length(units),buf_size-1)
    if !isempty(units)
        copyto!(buf,view(units,1:copy_end))
    end
    buf[copy_end+1] = 0
    

    if (CImGui.InputTextMultiline(name,buf,length(buf),size))
        GC.@preserve buf result = unsafe_string(pointer(buf))
    end

    return result
end