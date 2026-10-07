
function slider(label::String,value::AbstractFloat,min::Real=0,max::Real=1)::Float32
    value_ref = Ref(Float32(value))
    CImGui.SliderFloat(label, value_ref, Float32(min), Float32(max))
    return value_ref[]
end

function slider(label::String,self::Vec2T,min::Real=0,max::Real=1)::Vec2F
    self_ref = Ref(Vec2F(self.x, self.y))
    CImGui.SliderFloat2(label, self_ref, Float32(min), Float32(max))
    return self_ref[]
end

function slider(label::String,self::Vec3T,min::Real=0,max::Real=1)::Vec3F
    self_ref = Ref(Vec3F(self.x, self.y, self.z))
    CImGui.SliderFloat3(label, self_ref, Float32(min), Float32(max))
    return self_ref[]
end

function slider(label::String,self::Vec4T,min::Real=0,max::Real=1)::Vec4F
    self_ref = Ref(Vec4F(self.x, self.y, self.z, self.w))
    CImGui.SliderFloat4(label, self_ref, Float32(min), Float32(max))
    return self_ref[]
end

function slider(label::String,self::Integer,min::Real=0,max::Real=1)::Int32
    self_ref = Ref(Int32(self))
    CimGui.InputFloat
    CImGui.SliderInt(label, self_ref, Int32(min), Int32(max))
    return self_ref[]
end

function slider(label::String,self::Vec2T{T},min::Real=0,max::Real=1)::Vec2T{Int32} where T <: Integer
    self_ref = Ref(Vec2T{Int32}(Int32(self.x), Int32(self.y)))
    CImGui.SliderInt2(label, self_ref, Int32(min), Int32(max))
    return self_ref[]
end

function slider(label::String,self::Vec3T{T},min::Real=0,max::Real=1)::Vec3T{Int32} where T <: Integer
    Integer
    self_ref = Ref(Vec3T{Int32}(self.x, self.y, self.z))
    CImGui.SliderInt3(label, self_ref, Int32(min), Int32(max))
    return self_ref[]
end

function slider(label::String,self::Vec4T{T},min::Real=0,max::Real=1)::Vec4T{Int32} where T <: Integer
    Integer
    self_ref = Ref(Vec4T{Int32}(self.x, self.y, self.z, self.w))
    CImGui.SliderInt4(label, self_ref, Int32(min), Int32(max))
    return self_ref[]
end

function input(label::String,self::AbstractFloat,step::Real=1,step_fast::Real=5)::Float32
    self_ref = Ref(Float32(self))
    CImGui.InputFloat(label,self_ref, Float32(step), Float32(step_fast))
    return self_ref[]
end

function input(label::String,self::Vec2T)::Vec2F
    vec = @MVector[Float32(self.x), Float32(self.y)]
    CImGui.InputFloat2(label, vec)
    return Vec2F(vec[1], vec[2])
end

function input(label::String,self::Vec3T)::Vec3F
    vec = @MVector[Float32(self.x), Float32(self.y), Float32(self.z)]
    CImGui.InputFloat3(label, vec)
    return Vec3F(vec[1], vec[2], vec[3])
end

function input(label::String,self::Vec4T)::Vec4F
    vec = @MVector[Float32(self.x), Float32(self.y), Float32(self.z), Float32(self.w)]
    CImGui.InputFloat4(label, vec)
    return Vec4F(vec[1], vec[2], vec[3], vec[4])
end

function input(label::String,self::Integer,step::Real=1,step_fast::Real=5)::Int32
    self_ref = Ref(Int32(self))
    CImGui.InputInt(label, self_ref, Int32(step), Int32(step_fast))
    return Int(self_ref[])
end

function input(label::String,self::Vec2T{T})::Vec2T{Int32} where T <: Integer
    vec = @MVector[Int32(self.x), Int32(self.y)]
    CImGui.InputInt2(label, vec)
    return Vec2T(vec[1], vec[2])
end

function input(label::String,self::Vec3T{T})::Vec3T{Int32} where T <: Integer
    vec = @MVector[Int32(self.x), Int32(self.y), Int32(self.z)]
    CImGui.InputInt3(label, vec)
    return Vec3T(vec[1], vec[2], vec[3])
end

function input(label::String,self::Vec4T{T})::Vec4T{Int32} where T <: Integer
    vec = @MVector[Int32(self.x), Int32(self.y), Int32(self.z), Int32(self.w)]
    CImGui.InputInt4(label, vec)
    return Vec4T(vec[1], vec[2], vec[3], vec[4])
end

function color_edit3(label::String,color::UInt32)::UInt32
    c4 = unpack_color(color)
    col = @MVector[Float32(c4[1]), Float32(c4[2]), Float32(c4[3])]
    flags = CImGui.ImGuiColorEditFlags_NoInputs |
            CImGui.ImGuiColorEditFlags_NoLabel
    CImGui.ColorEdit3(label, col, flags)
    return get_color((col[1],col[2],col[3]))
end

function color_edit4(label::String,color::UInt32)::UInt32
    c4 = unpack_color(color)
    col = @MVector[Float32(c4[1]), Float32(c4[2]), Float32(c4[3]), Float32(c4[4])]
    flags = CImGui.ImGuiColorEditFlags_NoInputs |
        CImGui.ImGuiColorEditFlags_AlphaBar     |
        CImGui.ImGuiColorEditFlags_NoLabel
    CImGui.ColorEdit4(label, col, flags)
    return get_color((col[1], col[2], col[3], col[4]))
end

function input(label::String,text::String,buf_size=1024)::String
    result::String = text
    buf = get_bytebuffer(text, buf_size)
    if (CImGui.InputText(label,buf,length(buf)))
        GC.@preserve buf result = unsafe_string(pointer(buf), buf_size)
    end

    return result
end

function input_multiline(label::String,text::String,buf_size=1024,size=CImGui.ImVec2(CImGui.GetContentRegionAvail().x,100))::String
    result::String = text
    buf = get_bytebuffer(text, buf_size)
    
    if (CImGui.InputTextMultiline(label, buf, length(buf), size))
        GC.@preserve buf result = unsafe_string(pointer(buf), buf_size)
    end

    return result
end

function get_bytebuffer(text::String,buf_size::Unsigned=1024)::Vector{UInt8}
    buf = Vector{UInt8}(undef, buf_size)
    units = codeunits(text)

    copy_end = min(length(units), buf_size-1)

    while !isvalid(String(view(units, 1:copy_end)))
        copy_end-=1
    end

    if !isempty(units)
        copyto!(buf, view(units,1:copy_end))
    end
    buf[copy_end+1] = 0
    return buf
end

function get_button_size(text::String)::Tuple{Float32, Float32}
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