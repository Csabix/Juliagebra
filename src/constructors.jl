# ! All exported constructors should be defined, and exported from here.

const DependentsT = Vector{T} where T <: PlanDNA
const DEFAULT_CALLBACK = () -> (return nothing)

# ? ---------------------------------
# ! GenericDependent
# ? ---------------------------------

function _GenericDependent(;
                _app::App = implicitApp,
                _call::Function = () -> (return nothing),
                _deps::DependentsT = Vector{PlanDNA}(),
                _startT::T
)::GenericDependentPlan{T} where {T}
    plan = GenericDependentPlan{T}(_call,_deps,_startT)
    submit!(_app,plan)
    return plan
end

GenericDependent(startT::T) where {T} = 
_GenericDependent(_startT = startT)

# ? Works, because Julia can figure out I'm just changing the syntax
# ? and T can be inferred in _GenericDependent
GenericDependent{T}(startT) where {T} = 
_GenericDependent(_startT = T(startT))

GenericDependent(callback::Function,startT::T,dependents::DependentsT) where {T} = 
_GenericDependent(_call = callback, _startT = startT, _deps = dependents)

GenericDependent{T}(callback::Function,startT,dependents::DependentsT) where {T} = 
_GenericDependent(_call = callback, _startT = T(startT), _deps = dependents)

# ? ---------------------------------
# ! Point
# ? ---------------------------------

function _Point(;
                _app::App = implicitApp,
                _call::Function = DEFAULT_CALLBACK,
                _deps::DependentsT = Vector{PlanDNA}(),
                _x = 0,
                _y = 0,
                _z = 0,
                )::PointPlan
    
    if (_call === DEFAULT_CALLBACK)
        _call = () -> (return Vec3D(_x,_y,_z))
    end
                
    plan = PointPlan(_call,_deps,_x,_y,_z)
    submit!(_app,plan)
    return plan
end

Point(x::Real,y::Real,z::Real) = 
_Point(_x=x,_y=y,_z=z)

Point(callback::Function,dependents::DependentsT) = 
_Point(_call=callback,_deps=dependents)


# ? ---------------------------------
# ! ParametricCurve
# ? ---------------------------------

function _ParametricCurve(;
                         _app::App = implicitApp,
                         _call::Function = () -> (),
                         _deps::DependentsT = Vector{PlanDNA}(),
                         _range= range(0.0,1.0,length=1000),
                         _col= (0.6,0.6,0.9),
                         _type= CURVE_SOLID,
                         _reversed= 0,
                         _width= 5.0f0
                         )::ParametricCurvePlan
    plan = ParametricCurvePlan(_call,_deps,_range,_col,_type,_reversed,_width)
    submit!(_app,plan)
    return plan
end

"""
    ParametricCurve(callback, range, [dependents]; kwargs...) -> ParametricCurvePlan

Construct a plan for a parametric curve defined by a generator function over a specific interval.

# Arguments
- `callback::Function`: A function (typically `t,dependents... -> Point`) that defines the curve's path.
- `range::AbstractRange{Float64}`: The interval and step size over which the `callback` is evaluated.
- `dependents::DependentsT`: A collection of `PlanDNA` objects that this curve depends on. Defaults to an empty vector.

# Keyword Arguments
- `color=(0.6, 0.6, 0.9)`: The RGB tuple or array of tuples defining the curve's color.
- `width=5.0f0`: The line thickness.
- `type=CURVE_SOLID`: The visual style of the curve (e.g., solid, dashed).
- `reversed=false`: Whether to flip the line pattern.

# Returns
- `ParametricCurvePlan`: A `PlanDNA` for further use in dependencies.

# Example
App();

curve = ParametricCurve(t -> (cos(t), sin(t), 0.0), 0:0.1:2π; color=(1, 0, 0));

play!();
"""
ParametricCurve(callback::Function,range::AbstractRange{Float64},dependents::DependentsT=Vector{PlanDNA}();
                color=(0.6,0.6,0.9),width=5.0f0,type=CURVE_SOLID,reversed=false)::ParametricCurvePlan =
_ParametricCurve(_call=callback,_deps=dependents,_range=range,_col=color,_type=type,_reversed=reversed ? 0x1 : 0x0,_width=width)

# ? ---------------------------------
# ! Segment
# ? ---------------------------------

"""
    Segment(first, second; kwargs...) -> ParametricCurvePlan

Construct a plan for a straight line segment connecting two points.

# Arguments
- `first::PointPlan`: The starting point of the segment.
- `second::PointPlan`: The ending point of the segment.

# Keyword Arguments
- `color=(0.6, 0.6, 0.9)`: The RGB tuple or array of tuples defining the segment's color.
- `width=5.0f0`: The line thickness.
- `type=CURVE_SOLID`: The visual style of the curve (e.g., solid, dashed).
- `reversed=false`: Whether to flip the line pattern.

# Returns
- `ParametricCurvePlan`: A `PlanDNA` representing the linear path between the two points.

# Example
App();

Segment(Point(0,0,0),Point(1,1,1));

play!();
"""
function Segment(first::PointPlan,second::PointPlan;
                 color=(0.6,0.6,0.9),width=5.0f0,type=CURVE_SOLID,reversed=false)::ParametricCurvePlan
    return ParametricCurve(range(0,1,length=2),[first,second],color=color,type=type,width=width,reversed=reversed) do t,a,b
        return b .* t .+ (1-t) .* a
    end
end

# ? ---------------------------------
# ! Intersections
# ? ---------------------------------

function _Curve2CurveIntersection(;
                                 _app::App = implicitApp,                
                                 _curve1::ParametricCurvePlan,
                                 _curve2::ParametricCurvePlan,
                                 _intersectNum
                                 )::Curve2CurveIntersectionPlan
    plan = Curve2CurveIntersectionPlan(_curve1,_curve2,UInt(_intersectNum))
    submit!(_app,plan)
    return plan
end

Intersection(curve1::ParametricCurvePlan,curve2::ParametricCurvePlan,intersectionNum) =
_Curve2CurveIntersection(_curve1=curve1,_curve2=curve2,_intersectNum=intersectionNum)

function _Curve2SurfaceIntersection(;
                                   _app::App = implicitApp,
                                   _curve::ParametricCurvePlan,
                                   _surface::ParametricSurfacePlan,
                                   _intersectNum
                                   )::Curve2SurfaceIntersectionPlan
    plan = Curve2SurfaceIntersectionPlan(_curve,_surface,UInt(_intersectNum))
    submit!(_app,plan)
    return plan
end

Intersection(curve::ParametricCurvePlan,surface::ParametricSurfacePlan,intersectionNum) =
_Curve2SurfaceIntersection(_curve=curve,_surface=surface,_intersectNum=intersectionNum)

function _Surface2SurfaceIntersection(;
                                   _app::App = implicitApp,
                                   _surface1::ParametricSurfacePlan,
                                   _surface2::ParametricSurfacePlan,
                                   _intersectNum
                                   )::Surface2SurfaceIntersectionPlan
    plan = Surface2SurfaceIntersectionPlan(_surface1,_surface2,UInt(_intersectNum))
    submit!(_app,plan)
    return plan
end

Intersection(surface1::ParametricSurfacePlan,surface2::ParametricSurfacePlan,intersectionNum) =
_Surface2SurfaceIntersection(_surface1=surface1,_surface2=surface2,_intersectNum=intersectionNum)

# ? ---------------------------------
# ! Mesh
# ? ---------------------------------

function Mesh(vertexes,normals,color,app::App)::MeshDependentPlan
    plan = MeshDependentPlan(vertexes,normals,color)
    submit!(app,plan)
    return plan
end

Mesh(vertexes,normals,color) =
Mesh(vertexes,normals,color,implicitApp)

# ? ---------------------------------
# ! ParametricSurface
# ? ---------------------------------

function _ParametricSurface(;
                           _app::App = implicitApp,
                           _call::Function = () -> (),
                           _deps::DependentsT = Vector{PlanDNA}(),
                           _width = 50,
                           _height = 50,
                           _uStart = 0.0,
                           _uEnd = 1.0,
                           _vStart = 0.0,
                           _vEnd = 0.0,
                           _color = (0.8,0.0,0.3),
                           _transparent = false
                           )::ParametricSurfacePlan
    plan = ParametricSurfacePlan(_call,_deps,_width,_height,_uStart,_uEnd,_vStart,_vEnd,_color,_transparent)
    submit!(_app,plan)
    return plan
end

ParametricSurface(callback::Function,width,height,uStart,uEnd,vStart,vEnd,dependents::DependentsT;transparent::Bool=false) =
_ParametricSurface(_call=callback,_width=width,_height=height,_uStart=uStart,_uEnd=uEnd,_vStart=vStart,_vEnd=vEnd,_deps=dependents,_transparent=transparent)

ParametricSurface(callback::Function,width,height,uStart,uEnd,vStart,vEnd;transparent::Bool=false) =
_ParametricSurface(_call=callback,_width=width,_height=height,_uStart=uStart,_uEnd=uEnd,_vStart=vStart,_vEnd=vEnd,_transparent=transparent)

# ? ---------------------------------
# ! Toggle
# ? ---------------------------------

function _Toggle(;
                _app::App = implicitApp,
                _call::Function = () -> (return nothing),
                _deps::DependentsT = Vector{PlanDNA}(),
                )::TogglePlan
    plan = TogglePlan(_call,_deps)
    submit!(_app,plan)
    return plan
end

Toggle() =
_Toggle()

Toggle(callback::Function,dependents::DependentsT) =
_Toggle(_call = callback, _deps=dependents)

# ? ---------------------------------
# ! Slider
# ? ---------------------------------

function _Slider(;
                _app::App = implicitApp,
                _call::Function = () -> (return nothing),
                _deps::DependentsT = Vector{PlanDNA}(),
                _minVal = 0.0,
                _startVal = 0.5,
                _maxVal = 1.0
                )::SliderPlan
    plan = SliderPlan(_call,_deps,_minVal,_startVal,_maxVal)
    submit!(_app,plan)
    return plan
end

Slider() =
_Slider()

Slider(minVal,maxVal) =
_Slider(_minVal = minVal, _startVal = ((maxVal - minVal)*0.5) + minVal ,_maxVal = maxVal)

Slider(minVal,startVal,maxVal) = 
_Slider(_minVal = minVal, _startVal = clamp(startVal,minVal,maxVal) ,_maxVal = maxVal)

Slider(callback::Function,minVal,maxVal,dependents::DependentsT) =
_Slider(_call = callback, _minVal = minVal ,_maxVal = maxVal, _deps=dependents)

# ? ---------------------------------
# ! TextBox
# ? ---------------------------------

function _TextBox(;
                _app::App = implicitApp,
                _call::Function = () -> (return nothing),
                _deps::DependentsT = Vector{PlanDNA}(),
                _text::String = ""
                )::TextBoxPlan
    plan = TextBoxPlan(_call,_deps,_text)
    submit!(_app,plan)
    return plan
end

TextBox() =
_TextBox()

TextBox(text) =
_TextBox(_text = text)

TextBox(callback::Function,dependents::DependentsT) =
_TextBox(_call = callback, _deps = dependents)

# ? ---------------------------------
# ! Sphere
# ? ---------------------------------

function _Sphere(;
                _app::App = implicitApp,
                _call::Function = () -> (return nothing),
                _deps::DependentsT = Vector{PlanDNA}(),
                _x::Float64 = 0.0,
                _y::Float64 = 0.0,
                _z::Float64 = 0.0,
                _r::Float64 = 1.0,
                _col = (0.980,0.467,0.306),
                _transparent = false
                )::SpherePlan
    plan = SpherePlan(_call,_deps,_x,_y,_z,_r,_col,_transparent)
    submit!(_app,plan)
    return plan
end

Sphere() =
_Sphere()

Sphere(x,y,z,r) =
_Sphere(_x = Float64(x), _y = Float64(y), _z = Float64(z), _r = Float64(r))

function Sphere(center::PointPlan,p1::PointPlan; color = (0.980,0.467,0.306), transparent = false)::SpherePlan
    deps = Vector{PlanDNA}([center,p1])
    call = function (center,p1)
        radius = norm(center - p1) 
        return (center,radius)
    end

    return _Sphere(_call = call, _deps = deps, _col = color, _transparent = transparent)
end

function Sphere(center::PointPlan,radius::GenericDependentPlan{Float64}; color = (0.031,0.337,0.412), transparent = false)
    deps = Vector{PlanDNA}([center,radius])
    call = function (center,radius)
        return (center,radius)
    end

    return _Sphere(_call = call, _deps = deps, _col = color, _transparent = transparent)
end

function plane2planeIntersection(plane_n1,plane_n2,plane_p1,plane_p2)
    
    plane_d1 = dot(-plane_n1,plane_p1)
    plane_d2 = dot(-plane_n2,plane_p2)

    plane_n3 = cross(plane_n1,plane_n2)
    
    determinant = (norm(plane_n3))^2

    line_p3 = Vec3D(NaN64,NaN64,NaN64)
    if (determinant != 0.0)
        line_p3 = (cross(plane_n3,plane_n2) * plane_d1 + cross(plane_n1,plane_n3) * plane_d2) / determinant
    end

    return (Vec3D(plane_n3),Vec3D(line_p3))
end

function line2PlaneIntersection(line_n,line_p,plane_n,plane_p)
    t = dot(plane_p-line_p,plane_n) / dot(line_n,plane_n)
    return line_p + t * line_n   
end

function sameDistancePlane(p1,p2)
    plane_n = p2 - p1
    plane_c = ((p2 - p1) / 2.0) + p1
    return (plane_n,plane_c)
end

function sphereCenter(p1,p2,p3,p4)
    plane_n12,plane_c12 = sameDistancePlane(p1,p2)
    plane_n34,plane_c34 = sameDistancePlane(p3,p4)

    line_n_12_34,line_p_12_34 = plane2planeIntersection(plane_n12,plane_n34,plane_c12,plane_c34)
    
    plane_n23,plane_c23 = sameDistancePlane(p2,p3)

    c = line2PlaneIntersection(line_n_12_34,line_p_12_34,plane_n23,plane_c23)

    return c
end

function Sphere(p1::PointPlan,p2::PointPlan,p3::PointPlan,p4::PointPlan; color = (0.697,0.230,0.958))
    deps = [p1,p2,p3,p4]
    call = function (p1,p2,p3,p4)
        c = sphereCenter(p1,p2,p3,p4)
        r = norm(p1 - c)
        return (c,r)
    end

    return _Sphere(_call = call, _deps = deps, _col = color)
end

# ? ---------------------------------
# ! SceneLoader
# ? ---------------------------------

function load_scene(path)
    props = aiCreatePropertyStore();

    components_to_remove =
        aiComponent_TANGENTS_AND_BITANGENTS |
        aiComponent_COLORS |
        aiComponent_TEXCOORDS |
        aiComponent_BONEWEIGHTS |
        aiComponent_ANIMATIONS |
        aiComponent_LIGHTS |
        aiComponent_CAMERAS |
        aiComponent_MATERIALS |
        aiComponent_NORMALS

    aiSetImportPropertyInteger(props, AI_CONFIG_PP_RVC_FLAGS, components_to_remove);

    flags =
        aiProcess_Triangulate |
        aiProcess_JoinIdenticalVertices |
        aiProcess_GenSmoothNormals |
        aiProcess_RemoveComponent |
        aiProcess_FlipWindingOrder

    scene_ptr = aiImportFileExWithProperties(path, flags, C_NULL, props);

    aiReleasePropertyStore(props);

    if scene_ptr != C_NULL
        scene = unsafe_load(scene_ptr)
        
        for i in 1:scene.mNumMeshes
            mesh_ptr = unsafe_load(scene.mMeshes, i)
            mesh = unsafe_load(mesh_ptr)
            
            #name_ptr = pointer_from_objref(Ref(mesh.mName))
            #name = unsafe_string(name_ptr + 4, mesh.mName.length)

            pos_raw = unsafe_wrap(Array, mesh.mVertices, mesh.mNumVertices)
            positions = [Vec3F(v.x, v.z, v.y) for v in pos_raw]

            norm_raw = unsafe_wrap(Array, mesh.mNormals, mesh.mNumVertices)
            normals = [Vec3F(n.x, n.y, n.z) for n in norm_raw]

            indices = UInt32[]
            faces = unsafe_wrap(Array, mesh.mFaces, mesh.mNumFaces)
            for face in faces
                f_indices = unsafe_wrap(Array, face.mIndices, face.mNumIndices)
                append!(indices, f_indices)
            end

            plan = MeshPlan(DEFAULT_CALLBACK,Vector{PlanDNA}(),positions, normals, indices)
            submit!(implicitApp,plan)
        end
        
        aiReleaseImport(scene_ptr)
    end
end

export GenericDependent
export Point
export ParametricCurve
export Segment
export Intersection
export Mesh
export ParametricSurface
export Toggle
export Slider
export TextBox
export Sphere
export load_scene