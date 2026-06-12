
abstract type AppDNA end
abstract type ImGuiDNA end

abstract type WidgetDNA end
abstract type OpenGLWidgetDNA <: WidgetDNA end
abstract type ImGuiWidgetDNA <: WidgetDNA end
abstract type WindowDNA <: ImGuiWidgetDNA end

abstract type Primitive end
abstract type AABBPrimitive <: Primitive end
abstract type AABBPrimitive2D <: AABBPrimitive end
abstract type AABBPrimitive3D <: AABBPrimitive end

abstract type PrimitivesOf{T<:Primitive} end

const IntersectT= Union{Vec3D,Primitive}