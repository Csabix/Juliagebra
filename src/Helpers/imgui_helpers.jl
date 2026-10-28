
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
    CImGui.SliderInt(label, self_ref, Int32(min), Int32(max))
    return self_ref[]
end

function slider(label::String,self::Vec2T{T},min::Real=0,max::Real=1)::Vec2T{Int32} where T <: Integer
    self_ref = Ref(Vec2T{Int32}(Int32(self.x), Int32(self.y)))
    CImGui.SliderInt2(label, self_ref, Int32(min), Int32(max))
    return self_ref[]
end

function slider(label::String,self::Vec3T{T},min::Real=0,max::Real=1)::Vec3T{Int32} where T <: Integer
    self_ref = Ref(Vec3T{Int32}(self.x, self.y, self.z))
    CImGui.SliderInt3(label, self_ref, Int32(min), Int32(max))
    return self_ref[]
end

function slider(label::String,self::Vec4T{T},min::Real=0,max::Real=1)::Vec4T{Int32} where T <: Integer
    self_ref = Ref(Vec4T{Int32}(self.x, self.y, self.z, self.w))
    CImGui.SliderInt4(label, self_ref, Int32(min), Int32(max))
    return self_ref[]
end

input(::String, ::Nothing) = nothing

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

function input_enum(label::String, names::Vector{String}, selection::T)::T where T <: Integer
    selection -=1
    if CImGui.BeginCombo(label, names[selection+1])
        for i in 0:length(names)-1
            is_selected = (selection == i)
            if CImGui.Selectable(names[i+1], is_selected)
                selection = i
            end
            if is_selected
                CImGui.SetItemDefaultFocus()
            end
        end
        CImGui.EndCombo()
    end
    return selection +1
end

function color_edit3(label::String,color::Integer)::UInt32
    c4 = unpack_color(UInt32(color))
    col = @MVector[Float32(c4[1]), Float32(c4[2]), Float32(c4[3])]
    flags = CImGui.ImGuiColorEditFlags_NoInputs |
            CImGui.ImGuiColorEditFlags_NoLabel
    CImGui.ColorEdit3(label, col, flags)
    return get_color((col[1],col[2],col[3]))
end

function color_edit4(label::String,color::Integer)::UInt32
    c4 = unpack_color(UInt32(color))
    col = @MVector[Float32(c4[1]), Float32(c4[2]), Float32(c4[3]), Float32(c4[4])]
    flags = CImGui.ImGuiColorEditFlags_NoInputs |
        CImGui.ImGuiColorEditFlags_AlphaBar     |
        CImGui.ImGuiColorEditFlags_NoLabel
    CImGui.ColorEdit4(label, col, flags)
    return get_color((col[1], col[2], col[3], col[4]))
end

function input_bitflags(label::String, value::Integer, used_bits::Unsigned=ndigits(typemax(typeof(value)), 2))
    bits_left = Int(used_bits)
    rt = 0
    while bits_left >0
        bitcount = used_bits-bits_left
        out = Ref((2^bitcount & value) != 0)
        CImGui.Checkbox(label*(used_bits>1 ? "$bitcount" : ""), out)
        rt |= Int(out[]) << bitcount
        bits_left-=1
    end
    return rt
end

function input(label::String, value::Bool)::Bool
    out = Ref(value)
    CImGui.Checkbox(label, out)
    return out[]
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

function get_bytebuffer(text::String,buf_size::Integer=1024)::Vector{UInt8}
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

abstract type PropertyHint end

struct PropertyHintSlider <: PropertyHint
    min::Real
    max::Real
    function PropertyHintSlider(min::Real = 0.0, max::Real = 1.0)
        new(min, max)
    end
end

struct PropertyHintNoEdit <: PropertyHint
    function PropertyHintNoEdit()
        new()
    end
end

struct PropertyHintColor <: PropertyHint
    input_alpha::Bool
    function PropertyHintColor(input_alpha::Bool = true)
        new(input_alpha)
    end
end

struct PropertyHintNumber <: PropertyHint
    step::Real
    step_fast::Real
    function PropertyHintNumber(step::Real=1.0, step_fast::Real=5.0)
        new(step, step_fast)
    end
end


struct PropertyHintText <: PropertyHint
    buffer_size::Int
    function PropertyHintText(buffer_size::Int=1024)
        new(buffer_size)
    end
end

struct PropertyHintTextMultiline <: PropertyHint
    buffer_size::Int
    textbox_size::Vec2F
    function PropertyHintTextMultiline(buffer_size::Int=1024, textbox_size::CImGui.ImVec2 = CImGui.ImVec2(CImGui.GetContentRegionAvail().x,100))
        new(buffer_size, textbox_size)
    end
end

struct PropertyHintBitFlags <: PropertyHint
    bitcount::UInt32
    function PropertyHintBitFlags(bitcount::Integer = 32)
        new(UInt32(bitcount))
    end
end

struct PropertyHintEnum <:PropertyHint
    values::Vector{String}
    function PropertyHintEnum(values::Vector{String})
        @assert length(values)>0
        new(values)
    end
end

get_property_hint(element::Any, property::Symbol)::Union{PropertyHint, Nothing} = nothing

function input_property(label::String, value::Vector, property_hint::Union{PropertyHint, Nothing} = nothing)::Vector
        if length(value) == 1
            return [input_property(label, value[1], property_hint)]
        elseif 2<=length(value) <= 4 && (property_hint === nothing || property_hint isa PropertyHintNumber)
            types = map(v->typeof(v), value)
            if all(t -> t<:Real, types) && allequal(types)
                vec = nothing
                type = types[1]
                if length(value) == 2
                    vec = Vec2T{type}(value[1], value[2])
                elseif length(value)==3
                    vec = Vec3T{type}(value[1], value[2], value[3])
                else
                    vec = Vec3T{type}(value[1], value[2], value[3], value[4])
                end
                res = input_property(label, vec, property_hint)
                return [v for v in res]
            end
        end

        rt::Vector = []
        for v in eachindex(value)
            push!(rt, input_property(label*"$v", value[v], property_hint))
        end
        return rt
end

function input_property(label::String, value::T, property_hint::Union{PropertyHint, Nothing} = nothing)::T where T
    if property_hint isa PropertyHintColor
        if (property_hint::PropertyHintColor).input_alpha
            return color_edit4(label, value)
        else
            return color_edit3(label, value)
        end
    elseif property_hint isa PropertyHintSlider
        ps::PropertyHintSlider = property_hint::PropertyHintSlider
        return slider(label, value, ps.min, ps.max)
    elseif property_hint isa PropertyHintNumber
        pn::PropertyHintNumber = property_hint
        return input(label, value, pn.step, pn.step_fast)
    elseif property_hint isa PropertyHintText
        pt::PropertyHintText = property_hint
        return input(label, value, pt.buffer_size)
    elseif property_hint isa PropertyHintTextMultiline
        pm::PropertyHintTextMultiline = property_hint
        return input_multiline(label, value, pm.buffer_size, pm.textbox_size)
    elseif property_hint isa PropertyHintBitFlags
        pb::PropertyHintBitFlags = property_hint
        return input_bitflags(label, value, pb.bitcount)
    elseif property_hint isa PropertyHintEnum
        pe::PropertyHintEnum = property_hint
        return input_enum(label, pe.values, value)
    elseif property_hint isa PropertyHintNoEdit || !hasmethod(input, Tuple{String, T})
        CImGui.Text("$label: $value")
        return value
    else
        return input(label, value)
    end
end
