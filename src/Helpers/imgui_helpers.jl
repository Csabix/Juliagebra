
function slider1(self::T,text::String,min::AbstractFloat,max::AbstractFloat)::T where T
    self_ref = Ref(self)
    CImGui.SliderFloat(text,self_ref,min,max)
    return self_ref[]
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