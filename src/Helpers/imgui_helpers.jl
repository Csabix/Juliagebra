
function slider1(value::AbstractFloat,text::String,min::AbstractFloat,max::AbstractFloat)::Float32
    value_ref = Ref(Float32(value))
    CImGui.SliderFloat(text,value_ref,min,max)
    return value_ref[]
end

function slider3(self::Vec3T,text::String,min::AbstractFloat,max::AbstractFloat)::Vec3T
    self_ref = Ref(self)
    CImGui.SliderFloat3(text,self_ref,min,max)
    return self_ref[]
end

function slider1i(self::Int32,text::String,min::Integer,max::Integer)::Int32
    self_ref = Ref(self)
    CImGui.SliderInt(text,self_ref,min,max)
    return self_ref[]
end

function input1(self::Float32, label::String, step::Float32, step_fast::Float32)::Float32
    self_ref = Ref(self)
    CImGui.InputFloat(label, self_ref, step, step_fast)
    return self_ref[]
end

function input3(self::Vec3T, label::String)::Vec3T
    vec = @MVector[Float32(self.x), Float32(self.y), Float32(self.z)]
    CImGui.InputFloat3(label, vec)
    return Vec3T(vec[1], vec[2], vec[3])
end

function input1i(self::Int, label::String, step::Int, step_fast::Int)::Int
    self_ref = Ref(Int32(self))
    CImGui.InputInt(label, self_ref, Int32(step), Int32(step_fast))
    return Int(self_ref[])
end

function getButtonSize(text::String)::Tuple{Float32, Float32}
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
function color_edit3(color::UInt32, label::String)::UInt32
    c4 = unpack_color(color)
    col = @MVector[Float32(c4[1]), Float32(c4[2]), Float32(c4[3])]
    flags = CImGui.ImGuiColorEditFlags_NoInputs |
            CImGui.ImGuiColorEditFlags_NoLabel
    CImGui.ColorEdit3(label, col, flags)
    return get_color((col[1],col[2],col[3]))
end

function color_edit4(color::UInt32, label::String)::UInt32
    c4 = unpack_color(color)
    col = @MVector[Float32(c4[1]), Float32(c4[2]), Float32(c4[3]), Float32(c4[4])]
    flags = CImGui.ImGuiColorEditFlags_NoInputs |
        CImGui.ImGuiColorEditFlags_AlphaBar     |
        CImGui.ImGuiColorEditFlags_NoLabel
    CImGui.ColorEdit4(label, col, flags)
    return get_color((col[1], col[2], col[3], col[4]))
end

function txtbox(name::String,text::String,buf_size=1024,size=CImGui.ImVec2(CImGui.GetContentRegionAvail().x,100))::Union{String,Nothing}
    result::Union{String,Nothing} = nothing
    buf = Vector{UInt8}(undef,buf_size)
    units = codeunits(text)

    copy_end = min(length(units),buf_size-1)

    while !isvalid(String(view(units,1:copy_end)))
        copy_end-=1
    end

    if !isempty(units)
        copyto!(buf,view(units,1:copy_end))
    end
    buf[copy_end+1] = 0
    

    if (CImGui.InputTextMultiline(name,buf,length(buf),size))
        GC.@preserve buf result = unsafe_string(pointer(buf))
    end

    return result
end