const AXIS_NONE::UInt32 = UInt32(0x0)
const AXIS_X::UInt32    = UInt32(0x1)
const AXIS_Y::UInt32    = UInt32(0x2)
const AXIS_Z::UInt32    = UInt32(0x4)
const AXIS_FULL::UInt32 = UInt32(0x7)
export AXIS_NONE, AXIS_X, AXIS_Y, AXIS_Z, AXIS_FULL

const AXIS_TO_VECTOR = Dict{UInt32,Vec3F}(
    AXIS_X => Vec3F(1,0,0),
    AXIS_Y => Vec3F(0,1,0),
    AXIS_Z => Vec3F(0,0,1),
)
const ALL_AXES = UInt32[AXIS_X, AXIS_Y, AXIS_Z]
const MIN_VIEW_ANGLE_DIFF::Float32 = abs(sin(deg2rad(2.0)))

mutable struct GizmoRenderer <: Renderer
    corner_gizmo::Pipeline
    move_gizmo::Pipeline
    position::Vec3D
    initial_plane_normal::Vec3D
    initial_ray_diff::Vec3D
    axes::UInt32
    
    initial_constraints::UInt32
    move::Bool
    first_move::Bool
    selected::UInt32
    selectedAxis::UInt32
    lastMousePosition::Tuple{Float64,Float64}
    data::Any

    # ? 3 floats for position, 4th float for axes visibility
    ubo_axis::MappedBuffer{Vec4F}
    # ? 1 float for length + 1 float for thickness
    ubo_size::MappedBuffer{Float32}
    empty_vao::VertexArray

    function GizmoRenderer(loader::PipelineLoader,content_scale::Float32)
        corner_gizmo = create_graphics_pipeline!(loader;
            vert = (spv"renderers/gizmo/gizmo.vert",Tuple{GLuint,GLuint}[(0,1),(1,reinterpret(GLuint,content_scale))]),
            geom = (spv"renderers/gizmo/gizmo.geom",Tuple{GLuint,GLuint}[(0,1),(1,reinterpret(GLuint,content_scale))]),
            frag = spv"renderers/gizmo/gizmo.frag"
        )

        move_gizmo = create_graphics_pipeline!(loader;
            vert = (spv"renderers/gizmo/gizmo.vert",Tuple{GLuint,GLuint}[(0,0),(1,reinterpret(GLuint,content_scale))]),
            geom = (spv"renderers/gizmo/gizmo.geom",Tuple{GLuint,GLuint}[(0,0),(1,reinterpret(GLuint,content_scale))]),
            frag = spv"renderers/gizmo/gizmo.frag"
        )
        position = Vec3D(0.0)
        initial_plane_normal = Vec3D(0.0)
        initial_ray_diff = Vec3F(0.0)
        axes = AXIS_NONE
        
        initial_constraints = AXIS_NONE
        move = false
        first_move = true
        selected = UInt32(0)
        selectedAxis = UInt32(0)
        lastMousePosition = (Float64(0), Float64(0))
        data = nothing

        ubo_axis = MappedBuffer{Vec4F}()
        reserve!(ubo_axis, 1, 0)
        ubo_size = MappedBuffer{Float32}()
        reserve!(ubo_size, 2, 0)
        ubo_size[1] = 1.0
        ubo_size[2] = 1.0

        empty_vao = VertexArray()
        return new(
            corner_gizmo,move_gizmo,position,initial_plane_normal,initial_ray_diff,axes,
            initial_constraints,move,first_move,selected,selectedAxis,lastMousePosition,data,
            ubo_axis,ubo_size,empty_vao
        )
    end
end

function clear!(renderer::GizmoRenderer)::Nothing
    renderer.axes = AXIS_NONE
    renderer.initial_constraints = AXIS_NONE
    renderer.move = false
    renderer.data = nothing
    return nothing
end

function destroy!(renderer::GizmoRenderer)::Nothing
    destroy!(renderer.ubo_axis)
    destroy!(renderer.ubo_size)
    return nothing
end

function pre_draw!(renderer::GizmoRenderer,cam::Camera,window::GLFWData)::Nothing
    if renderer.axes == AXIS_NONE return nothing end
    wait(renderer.ubo_axis)
    renderer.ubo_axis[1] = Vec4F(
        Float32(renderer.position[1]),
        Float32(renderer.position[2]),
        Float32(renderer.position[3]),
        reinterpret(Float32, renderer.axes)
    )
    return nothing
end

function draw_ui!(renderer::GizmoRenderer,cam::Camera,window::GLFWData)::Nothing
    activate(renderer.empty_vao)
    activate(renderer.corner_gizmo)
    glDrawArrays(GL_LINES, 0, 12)

    if renderer.axes == AXIS_NONE return nothing end

    bind_ubo(renderer.ubo_axis, 0)
    bind_ubo(renderer.ubo_size, 1)
    activate(renderer.move_gizmo)
    glDrawArrays(GL_LINES, 0, 12)
    lock(renderer.ubo_axis)

    return nothing
end

function _planeLineIntersection(eye::Vec3D, ray::Vec3D, plane_position::Vec3D, plane_normal::Vec3D)::Union{Vec3D,Nothing}
    cosRayNormal = dot(ray, plane_normal)
    if (cosRayNormal == 0.0) return nothing end

    t = dot(plane_position - eye, plane_normal) / cosRayNormal
    if (t >= 0)
        return eye + t * ray
    else
        return nothing
    end
end
function _moveAlongAxis(app, gizmo::GizmoRenderer, ray::Vec3F, origin::Vec3F)::Union{Vec3D,Nothing}
    axis_vector = AXIS_TO_VECTOR[gizmo.axes]
    if (gizmo.first_move)
        # ? Perpendicular to ray and the axis
        perp = cross(ray, axis_vector)
        # ? Plane normal is perpendicular to previous vector and the axis
        gizmo.initial_plane_normal = cross(perp, axis_vector)
    end
    
    angleDiff = dot(normalize(app._cam.at - app._cam.eye), normalize(gizmo.initial_plane_normal))
    if (abs(angleDiff) >= MIN_VIEW_ANGLE_DIFF)
        intersection = _planeLineIntersection(Vec3D(origin), Vec3D(ray), gizmo.position, Vec3D(gizmo.initial_plane_normal))
        if (intersection !== nothing)
            # ? Projecting onto axis to get length
            t = dot(intersection - gizmo.position, axis_vector)
            return gizmo.position + t * axis_vector
        end
    end

    return nothing
end
function _moveAlongPlane(app, gizmo::GizmoRenderer, ray::Vec3F, origin::Vec3F)::Union{Vec3D,Nothing}
    for axis in ALL_AXES
        # ? Finds the perpendicular axis to the plane that'll be used as its normal
        if (gizmo.axes & axis == 0)
            angleDiff = dot(normalize(app._cam.at - app._cam.eye), normalize(AXIS_TO_VECTOR[axis]))
            if (abs(angleDiff) >= MIN_VIEW_ANGLE_DIFF)
                intersection = _planeLineIntersection(Vec3D(origin), Vec3D(ray), gizmo.position, Vec3D(AXIS_TO_VECTOR[axis]))
                if (intersection !== nothing)
                    return intersection
                end
            end
            break
        end
    end
    
    return nothing
end

function _move_gizmo!(app, gizmo::GizmoRenderer, mouseX, mouseY)::Bool
    if !gizmo.move || gizmo.axes == AXIS_NONE
        return false
    end
    ray = get_ray(app, mouseX, mouseY)
    origin = get_origin(app, mouseX, mouseY)
    newPoint = nothing
    
    if (gizmo.first_move)
        toPoint = normalize(gizmo.position - origin)
        # ? Stores the initial difference between where the eye-point vector and the eye-mouse ray
        gizmo.initial_ray_diff = toPoint - ray
    end

    # ? Applies the stored difference, so that the gizmo doesn't jump to the cursor at the beginning
    ray = Vec3F(ray + gizmo.initial_ray_diff)

    if (any(a -> a == gizmo.axes, ALL_AXES))
        newPoint = _moveAlongAxis(app, gizmo, ray, origin)
    else
        newPoint = _moveAlongPlane(app, gizmo, ray, origin)
    end

    if (gizmo.first_move && newPoint !== nothing)
        gizmo.first_move = false
    end

    if (newPoint !== nothing)
        gizmo.position = newPoint
    end

    if gizmo.selected > 3
        app.graph.elements[gizmo.selected], gizmo.data = on_gizmo_move(app.graph.elements[gizmo.selected],gizmo.position,gizmo.data)
        invalidate!(app.graph,NodeHandle(gizmo.selected))
        app._scene_change = true
    end
    return true
end

function on_gizmo_left_click!(app)::Bool
    gizmo::GizmoRenderer = app._opengl._renderers[GizmoRenderer]
    if 0 < app._hovered <= 3 # TODO: only when not moving yet
        gizmo.axes = ALL_AXES[app._hovered]

        gizmo.move = true
        gizmo.first_move = true
        _move_gizmo!(app, gizmo, gizmo.lastMousePosition[1], gizmo.lastMousePosition[2])

        app._scene_change = true
        return true
    end
    return false
end

function on_gizmo_right_click!(app)::Bool
    gizmo::GizmoRenderer = app._opengl._renderers[GizmoRenderer]
    if app._hovered > 3
        axes, gizmo_position, data = on_gizmo_select(app.graph.elements[app._hovered],app.graph.render_data[app._hovered])
        if (axes == AXIS_NONE || gizmo_position == Vec3DNan)
            return false
        else
            gizmo.data = data
            gizmo.initial_constraints = axes
            gizmo.axes = axes
            gizmo.position = gizmo_position
            gizmo.move = false
            gizmo.selected = app._hovered
            app._scene_change = true
            return true
        end
    end
    app._scene_change |= gizmo.axes != AXIS_NONE
    gizmo.data = nothing
    gizmo.axes = AXIS_NONE
    gizmo.initial_constraints = AXIS_NONE
    gizmo.move = false
    return false
end

function on_gizmo_left_release!(app)::Bool
    gizmo::GizmoRenderer = app._opengl._renderers[GizmoRenderer]
    if gizmo.move
        gizmo.axes = gizmo.initial_constraints
        gizmo.move = false
        app._scene_change = true
        return true
    end
    return false
end

function on_gizmo_drag!(app, event)::Bool
    gizmo::GizmoRenderer = app._opengl._renderers[GizmoRenderer]
    gizmo.lastMousePosition = (event.x, event.y)
    if !gizmo.move || (gizmo.axes == AXIS_NONE && gizmo.selectedAxis == AXIS_NONE)
        return false
    end

    _move_gizmo!(app, gizmo, event.x, event.y)
    return true
end

function on_gizmo_drag_axis_start!(app, axis)::Bool
    gizmo::GizmoRenderer = app._opengl._renderers[GizmoRenderer]
    if (gizmo.axes == 0 || gizmo.selectedAxis & axis > 0 || gizmo.selectedAxis | axis == AXIS_FULL)
        return false
    end

    gizmo.selectedAxis |= axis
    gizmo.axes = gizmo.selectedAxis

    gizmo.move = true
    gizmo.first_move = true
    _move_gizmo!(app, gizmo, gizmo.lastMousePosition[1], gizmo.lastMousePosition[2])

    app._scene_change = true
    return true
end
function on_gizmo_drag_axis_end!(app, axis)::Bool
    gizmo::GizmoRenderer = app._opengl._renderers[GizmoRenderer]
    if (gizmo.selectedAxis & axis == 0)
        return false
    end

    gizmo.selectedAxis -= axis
    gizmo.axes = gizmo.selectedAxis
    gizmo.first_move = true

    if (gizmo.selectedAxis == AXIS_NONE)
        gizmo.move = false
        gizmo.axes = gizmo.initial_constraints
    end

    app._scene_change = true
    return true
end