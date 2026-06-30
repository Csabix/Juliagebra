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

        ubo = MappedBuffer{Vec4F}()
        reserve!(ubo, 1, 0)

        empty_vao = VertexArray()
        return new(
            corner_gizmo,move_gizmo,position,axes,
            initial_constraints,move,id_to_axis,selected,
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

function _screen24(v::Vec4F)::Vec2F
    x = (v.x / v.w)
    y = (v.y / v.w)
    return Vec2F(x, y)
end

function screenVecs(origin, axis, x, y, width, height, vp)
    screenOrigin = vp * Vec4F(origin, 1.0)
    screenOrigin = _screen24(screenOrigin)

    screenAxis = vp * Vec4F(axis, 1.0)
    screenAxis = _screen24(screenAxis)

    screenMouse = Vec2F((x / width) * 2.0 - 1.0, (y / height) * 2.0 - 1.0)

    return (screenOrigin, screenAxis, screenMouse)
end

function _getAxisClampedT(axis_2d::Vec2F, mouse_2d::Vec2F)::Float32
    partOne = axis_2d.x * mouse_2d.x + axis_2d.y * mouse_2d.y
    partDiv = axis_2d.x * axis_2d.x + axis_2d.y * axis_2d.y
    if partDiv < 1e-6 return 0.0f0 end
    return partOne / partDiv
end

function on_gizmo_left_click!(app)::Bool
    gizmo = app._opengl._renderers.gizmo
    if 0 < app.hovered <= 3
        axes_map = UInt32[AXIS_X, AXIS_Y, AXIS_Z]
        gizmo.axes = axes_map[app.hovered]
        gizmo.move = true
        app._scene_change = true
        return true
    end
    return false
end

function on_gizmo_right_click!(app)::Bool
    gizmo = app._opengl._renderers.gizmo
    if app.hovered > 3
        p = getDependentNode(getModel(app), app.hovered - ID_LOWER_BOUND)
                
        if isa(p, PointDependent)
            pp::PointDependent = p
            gizmo.initial_constraints = pp._constraints
            gizmo.axes = pp._constraints
            gizmo.position = pp._coord
            gizmo.move = false
            gizmo.selected = app.hovered
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
    if !gizmo.move || gizmo.axes == AXIS_NONE
        return false
    end

    selected_axis_idx = gizmo.axes == AXIS_Y ? 2 : (gizmo.axes == AXIS_Z ? 3 : 1)
    
    vp, _, _ = get_matrices(app._cam)
    origin = Vec3F(gizmo.position)
    axis_vector = gizmo.id_to_axis[selected_axis_idx] + origin
    
    screen_origin, screen_axis, screen_mouse = screenVecs(origin, axis_vector, event.x, event.y, app._glfw.width, app._glfw.height, vp)
    t = _getAxisClampedT(screen_axis - screen_origin, screen_mouse - screen_origin)
    
    if norm(screen_axis - screen_origin) >= 0.01f0
        gizmo.position = Vec3D(origin + (axis_vector - origin) * t)
        
        if gizmo.selected > 3
            p::PointDependent = getDependentNode(getModel(app), gizmo.selected - ID_LOWER_BOUND)::PointDependent
            if p._coord != gizmo.position
                p._coord = gizmo.position
                # ? schedule for evalGraph
                schedule(getModel(app),p)
            end
        end
    end 
    
    return true
end