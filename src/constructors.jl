# ! All exported constructors should be defined, and exported from here.

macro Point(callback::Expr)
    callback = _validate_callback_expr(callback, 0)
    return _create_ctor_wrapper(callback, __module__, Juliagebra.Point)
end

macro ParametricCurve(callback::Expr,range,kw_args...)
    parsed_kw_args = _parse_macro_kw_args([:color, :width, :type, :reversed], kw_args...)
    callback = _validate_callback_expr(callback, 1)
    return _create_ctor_wrapper(callback, __module__, Juliagebra.ParametricCurve, (cb, deps) -> (cb, range, deps); parsed_kw_args...)
end

macro SegmentSequence(callback::Expr,break_every=2,kw_args...)
    (break_every, kw_args) = _kw_arg_or_default(break_every, 2, kw_args)

    parsed_kw_args = _parse_macro_kw_args([:color, :width, :type, :reversed], kw_args...)
    callback = _validate_callback_expr(callback, 0)
    return _create_ctor_wrapper(callback, __module__, Juliagebra.SegmentSequence, (cb, deps) -> (cb, deps, break_every); parsed_kw_args...)
end

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

macro ParametricSurface(callback::Expr,width,height,uStart,uEnd,vStart,vEnd,kw_args...)
    parsed_kw_args = _parse_macro_kw_args([:transparent, :color], kw_args...)
    callback = _validate_callback_expr(callback, 2)
    return _create_ctor_wrapper(callback, __module__, Juliagebra.ParametricSurface,
        (cb, deps) -> (cb, width, height, uStart, uEnd, vStart, vEnd, deps);
        parsed_kw_args...)
end

macro Toggle(callback::Expr)
    callback = _validate_callback_expr(callback, 0)
    return _create_ctor_wrapper(callback, __module__, Juliagebra.Toggle)
end

macro Slider(callback::Expr,minVal,maxVal)
    _validate_callback_expr(callback, 0)
    return _create_ctor_wrapper(callback, __module__, Juliagebra.Slider, (cb, deps) -> (cb,minVal,maxVal,deps))
end

macro TextBox(callback::Expr)
    callback = _validate_callback_expr(callback, 0)
    return _create_ctor_wrapper(callback, __module__, Juliagebra.TextBox)
end

macro PointCloud(callback::Expr, kw_args...)
    parsed_kw_args = _parse_macro_kw_args([:color, :width], kw_args...)
    callback = _validate_callback_expr(callback, 0)
    return _create_ctor_wrapper(callback, __module__, Juliagebra.PointCloud; parsed_kw_args...)
end


export @Point
export @ParametricCurve
export Segment
export SegmentSequence
export @SegmentSequence
export Mesh
export @ParametricSurface
export @Toggle
export @Slider
export @TextBox
export PointCloud
export @PointCloud
export _deps_collect