const AXIS_NONE::UInt32 = UInt32(0x0)
const AXIS_X::UInt32    = UInt32(0x1)
const AXIS_Y::UInt32    = UInt32(0x2)
const AXIS_Z::UInt32    = UInt32(0x4)
const AXIS_FULL::UInt32 = UInt32(0x7)
export AXIS_NONE, AXIS_X, AXIS_Y, AXIS_Z, AXIS_FULL

mutable struct GizmoRenderer
    corner_gizmo::Pipeline
    move_gizmo::Pipeline
    position::Vec3D
    axes::UInt32
    
    initial_constraints::UInt32
    move::Bool
    id_to_axis::Tuple{Vec3F,Vec3F,Vec3F}
    selected::UInt32
    selectedAxis::UInt32

    ubo::MappedBuffer{Vec4F}
    empty_vao::VertexArray

    function GizmoRenderer(loader::PipelineLoader,content_scale::Float32)
        corner_gizmo = create_graphics_pipeline!(loader;
            vert = (spv"renderers/gizmo/gizmo.vert",Tuple{GLuint,GLuint}[(0,1),(1,reinterpret(GLuint,content_scale))]),
            geom = (spv"renderers/gizmo/gizmo.geom",Tuple{GLuint,GLuint}[(1,reinterpret(GLuint,content_scale))]),
            frag = spv"renderers/gizmo/gizmo.frag"
        )

        move_gizmo = create_graphics_pipeline!(loader;
            vert = (spv"renderers/gizmo/gizmo.vert",Tuple{GLuint,GLuint}[(0,0),(1,reinterpret(GLuint,content_scale))]),
            geom = (spv"renderers/gizmo/gizmo.geom",Tuple{GLuint,GLuint}[(1,reinterpret(GLuint,content_scale))]),
            frag = spv"renderers/gizmo/gizmo.frag"
        )
        position = Vec3D(0.0)
        axes = AXIS_NONE
        
        initial_constraints = AXIS_NONE
        move = false
        id_to_axis = (Vec3F(1,0,0), Vec3F(0,1,0), Vec3F(0,0,1))
        selected = UInt32(0)
        selectedAxis = UInt32(0)

        ubo = MappedBuffer{Vec4F}()
        reserve!(ubo, 1, 0)

        empty_vao = VertexArray()
        return new(
            corner_gizmo,move_gizmo,position,axes,
            initial_constraints,move,id_to_axis,selected,selectedAxis,
            ubo,empty_vao
        )
    end
end

function reset!(renderer::GizmoRenderer)::Nothing
    renderer.axes = AXIS_NONE
    renderer.initial_constraints = AXIS_NONE
    renderer.move = false
    return nothing
end

function destroy!(renderer::GizmoRenderer)::Nothing
    destroy!(renderer.ubo)
    return nothing
end

function pre_draw(renderer::GizmoRenderer,cam::Camera,window::GLFWData)::Nothing
    if renderer.axes == AXIS_NONE return nothing end
    wait(renderer.ubo)
    renderer.ubo[1] = Vec4F(
        Float32(renderer.position[1]),
        Float32(renderer.position[2]),
        Float32(renderer.position[3]),
        reinterpret(Float32, renderer.axes)
    )
    return nothing
end

function draw_ui(renderer::GizmoRenderer,cam::Camera,window::GLFWData)::Nothing
    activate(renderer.empty_vao)
    activate(renderer.corner_gizmo)
    glDrawArrays(GL_LINES, 0, 12)

    if renderer.axes == AXIS_NONE return nothing end

    bind_ubo(renderer.ubo, 0)
    activate(renderer.move_gizmo)
    glDrawArrays(GL_LINES, 0, 12)
    lock(renderer.ubo)

    return nothing
end

function _seg2segSqDistParams(p::Vec3D,v::Vec3D,q::Vec3D,w::Vec3D)::Tuple{Float64,Float64,Float64}
    r  = q - p

    # v2, w2 : magnitudes^2
    # vw : parallellity
    v2 = dot(v,v); w2 = dot(w,w); vw = dot(v,w)

	D  = v2*w2 - vw*vw # ‖v×w‖²
    a1 = dot(v,r); a2 = dot(w,r); a3 = dot(cross(v,w), r)
	
    t  = ( w2*a1 - vw*a2 ) / D
    s  = ( vw*a1 - v2*a2 ) / D
	
    d2 = a3*a3 / D
	
    return (d2, t, s)
end

function _closestPointOnAxis(eye::Vec3D, ray::Vec3D, position::Vec3D, axis_vector::Vec3D)::Vec3D
    (_, _, s) = _seg2segSqDistParams(eye, ray, position, axis_vector)
    return Vec3D(position + axis_vector * s)
end
function _planeLineIntersection()
    # plane intersection
end

function on_gizmo_left_click!(app)::Bool
    gizmo = app._opengl._renderers.gizmo
    if 0 < app._hovered <= 3 # TODO: only when not moving yet
        axes_map = UInt32[AXIS_X, AXIS_Y, AXIS_Z]
        gizmo.axes = axes_map[app._hovered]
        gizmo.move = true
        app._scene_change = true
        return true
    end
    return false
end

function on_gizmo_right_click!(app)::Bool
    gizmo = app._opengl._renderers.gizmo
    if app._hovered > 3
        p = getDependentNode(getModel(app), app._hovered - ID_LOWER_BOUND)
                
        if isa(p, PointDependent)
            pp::PointDependent = p
            gizmo.initial_constraints = pp._constraints
            gizmo.axes = pp._constraints
            gizmo.position = pp._coord
            gizmo.move = false
            gizmo.selected = app._hovered
            app._scene_change = true
            return true
        end
    end
    app._scene_change |= gizmo.axes != AXIS_NONE
    gizmo.axes = AXIS_NONE
    gizmo.initial_constraints = AXIS_NONE
    gizmo.move = false
    return false
end

function on_gizmo_left_release!(app)::Bool
    gizmo = app._opengl._renderers.gizmo
    if gizmo.move
        gizmo.axes = gizmo.initial_constraints
        gizmo.move = false
        app._scene_change = true
        return true
    end
    return false
end

function on_gizmo_drag!(app, event)::Bool
    gizmo = app._opengl._renderers.gizmo
    if !gizmo.move || (gizmo.axes == AXIS_NONE && gizmo.selectedAxis == AXIS_NONE)
        return false
    end

    ray = get_ray(app, event.x, event.y)
    
    newPoint = Vec3D(0,0,0)
    if (gizmo.axes != AXIS_NONE)
        selected_axis_idx = gizmo.axes == AXIS_Y ? 2 : (gizmo.axes == AXIS_Z ? 3 : 1)
        axis_vector = gizmo.id_to_axis[selected_axis_idx]
        newPoint = _closestPointOnAxis(Vec3D(app._cam._eye), Vec3D(ray), gizmo.position, Vec3D(axis_vector))
    else
        # _planeLineIntersection()
        # TODO: plane intersection
    end

    gizmo.position = newPoint
    if gizmo.selected > 3
        p::PointDependent = getDependentNode(getModel(app), gizmo.selected - ID_LOWER_BOUND)::PointDependent
        if p._coord != gizmo.position
            p._coord = gizmo.position
            # ? schedule for evalGraph
            schedule(getModel(app),p)
        end
    end

    return true
end

function on_gizmo_drag_axis_start!(app, axis)::Bool
    gizmo = app._opengl._renderers.gizmo
    if (gizmo.selectedAxis & axis > 0 || gizmo.selectedAxis | axis == AXIS_FULL)
        return false
    end

    gizmo.selectedAxis |= axis
    gizmo.axes = gizmo.selectedAxis
    gizmo.move = true
    
    app._scene_change = true
    # println(gizmo.selectedAxis)
    return true
end
function on_gizmo_drag_axis_end!(app, axis)::Bool
    gizmo = app._opengl._renderers.gizmo
    if (gizmo.selectedAxis & axis == 0)
        return false
    end

    gizmo.selectedAxis -= axis
    gizmo.axes = gizmo.selectedAxis
    if (gizmo.selectedAxis == AXIS_NONE)
        gizmo.move = false
        gizmo.axes = gizmo.initial_constraints
    end

    app._scene_change = true
    # println(gizmo.selectedAxis)
    return true
end