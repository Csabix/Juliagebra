
# ? ---------------------------------
# ! ParametricSurfaceDependent
# ? ---------------------------------

mutable struct ParametricSurfaceDependent{Range<:AbstractRange} <: RenderedDependentDNA
    _renderedDependent::RenderedDependent
    
    _uvValues::FlatMatrix{Vec3D}
    _uvNormals::FlatMatrix{Vec3D}
    _layer::Int

    _uRange::Range
    _vRange::Range

    _color::UInt32

    # YELLOW Thread
    function ParametricSurfaceDependent(
        callback::Function,dependents::Vector{<:DependentDNA},
        uRange::Range,
        vRange::Range,
        color::UInt32,
        ) where {Range<:AbstractRange}

        rd = RenderedDependent(callback,dependents)
        uvValues = FlatMatrix{Vec3D}(length(uRange),length(vRange))        
        uvNormals = FlatMatrix{Vec3D}(length(uRange),length(vRange))

        new{Range}(rd,
            uvValues,
            uvNormals,
            0,
            uRange,
            vRange,
            color)
    end
end

_RenderedDependent_(self::ParametricSurfaceDependent)::RenderedDependent = return self._renderedDependent
Base.string(self::ParametricSurfaceDependent) = return "ParametricSurface"

evalCallbackDpReturn(self::ParametricSurfaceDependent,value,u,v) = self._uvValues[u,v] = Vec3D(value)
evalCallbackDpReturn(self::ParametricSurfaceDependent,value::Tuple,u,v) = self._uvValues[u,v] = Vec3D(value...)
evalCallbackDpReturn(self::ParametricSurfaceDependent,value::Vec3F,u,v) = self._uvValues[u,v] = Vec3D(value)
evalCallbackDpReturn(self::ParametricSurfaceDependent,value::Vec3D,u,v) = self._uvValues[u,v] = value
evalCallbackDpReturn(self::ParametricSurfaceDependent,::Nothing,u,v) = self._uvValues[u,v] = Vec3DNan

function setInlandNormal(self::ParametricSurfaceDependent,u,v)
    uVec = self._uvValues[u+1,v  ] - self._uvValues[u-1,v  ]
    vVec = self._uvValues[u  ,v+1] - self._uvValues[u  ,v-1]
    self._uvNormals[u,v] = normalize(cross(uVec,vVec))
end

function setEdgeNormal(self::ParametricSurfaceDependent,u,v)
    self._uvNormals[u,v] = Vec3F(0,0,0)
end

function setNormal(self::ParametricSurfaceDependent,u,v;
    right=self._uvValues[u+1,v  ],
    left =self._uvValues[u-1,v  ],
    down =self._uvValues[u  ,v+1],
    up   =self._uvValues[u  ,v-1])

    # TODO: Clampekkel megoldva?
    # TODO: Fuggosegi normalvektor szamitas, kicsi 0.0001 eplszilonokkal, helyben szamitva

    uVec = right - left
    vVec = down - up
    self._uvNormals[u,v] = normalize(cross(uVec,vVec))
end

# YELLOW Thread
# RED Thread
function onNodeEval(self::ParametricSurfaceDependent)
    for v in eachindex(self._vRange)
        for u in eachindex(self._uRange)
            uf::Float64 = self._uRange[u]
            vf::Float64 = self._vRange[v]
            
            evalCallbackDp(self;callbackParams = (uf,vf), returnParams = (u,v))
        end
    end
    
    for v in 2:(height(self._uvValues)-1)
        for u in 2:(width(self._uvValues)-1)
            setNormal(self,u,v)
        end
    end

    # * Upper row, (u=u;v=1)
    for u in 2:(width(self._uvValues)-1)
        setNormal(self,u,1,
        up=self._uvValues[u,1])
    end

    # * Bottom row, (u=u;v=height)
    for u in 2:(width(self._uvValues)-1)
        setNormal(self,u,height(self._uvValues),
        down=self._uvValues[u,height(self._uvValues)])
    end

    # * Left column, (u=1;v=v)
    for v in 2:(height(self._uvValues)-1)
        setNormal(self,1,v,
        left=self._uvValues[1,v])
    end

    # * Right column, (u=width;v=v)
    for v in 2:(height(self._uvValues)-1)
        setNormal(self,width(self._uvValues),v,
        right=self._uvValues[width(self._uvValues),v])
    end

    # * (1,1)
    setNormal(self,1,1,
        left = self._uvValues[1,1],
        up   = self._uvValues[1,1])

    # * (width,1)
    setNormal(self,width(self._uvValues),1,
        right = self._uvValues[width(self._uvValues),1],
        up    = self._uvValues[width(self._uvValues),1])

    # * (1,height)
    setNormal(self,1,height(self._uvValues),
        left  = self._uvValues[1,height(self._uvValues)],
        down  = self._uvValues[1,height(self._uvValues)])

    # * (width,height)
    setNormal(self,width(self._uvValues),height(self._uvValues),
        right = self._uvValues[width(self._uvValues),height(self._uvValues)],
        down  = self._uvValues[width(self._uvValues),height(self._uvValues)])

end

# ? For Intersectable ParametricSurfaces.

struct PTrianglesOfSurface <: PrimitivesOf{PTriangle}
    _surfaceTriangleIterator::TrianglesOf
end
PrimitivesOf(self::ParametricSurfaceDependent) = return PTrianglesOfSurface(TrianglesOf(self._uvValues))

Base.length(self::PTrianglesOfSurface) = return length(self._surfaceTriangleIterator)

Base.getindex(self::PTrianglesOfSurface, index::UInt)::PTriangle = return self._surfaceTriangleIterator[index]

Base.iterate(self::PTrianglesOfSurface, state = (1,1,1)) = return iterate(self._surfaceTriangleIterator,state)   

# ? ---------------------------------
# ! ParametricSurfaceRenderer
# ? ---------------------------------

mutable struct ParametricSurfaceRenderer <: RendererDNA{ParametricSurfaceDependent}
    _renderer::Renderer{ParametricSurfaceDependent}
    _renderers::PrimitiveRenderers
    _refs::Vector{UInt32}

    _indexes::Vector{UInt32}
    _vertexes::FlatMatrixManager{Vec3F}
    _normals::FlatMatrixManager{Vec3F}

    # GREEN Thread
    function ParametricSurfaceRenderer(context::OpenGLData)
        renderer = Renderer{ParametricSurfaceDependent}(context)
        refs = Vector{UInt32}()
        
        new(renderer,context._renderers,refs,
        Vector{UInt32}(),FlatMatrixManager{Vec3F}(),FlatMatrixManager{Vec3F}())
    end
end

_Renderer_(self::ParametricSurfaceRenderer) = return self._renderer
Base.string(self::ParametricSurfaceRenderer) = "ParametricSurfaceRenderer - [$(length(self._refs))]"

# GREEN Thread
function added!(self::ParametricSurfaceRenderer,surface::ParametricSurfaceDependent)
    width = length(surface._uRange)
    height = length(surface._vRange)

    initMatrix(self._vertexes,width,height,Vec3FNan)
    initMatrix(self._normals,width,height,Vec3FNan)
    triangulateInto!(self._indexes,self._vertexes,layers(self._vertexes))
    
    # ? copy values
    copy!(surface._uvValues,self._vertexes,layers(self._vertexes))
    copy!(surface._uvNormals,self._normals,layers(self._normals))
    surface._layer = layers(self._vertexes)

    aID = UInt32(getGraphID(surface) + ID_LOWER_BOUND)
    coords = get_triangulated(data(self._vertexes, surface._layer),self._vertexes,layers(self._vertexes))
    ref = add!(
        self._renderers.triangle,
        coords,
        mat4(1.0f0),
        surface._color,
        aID)
    push!(self._refs, ref)
end

# GREEN Thread
function sync!(self::ParametricSurfaceRenderer,surface::ParametricSurfaceDependent)
    copy!(surface._uvValues,self._vertexes,surface._layer)
    copy!(surface._uvNormals,self._normals,surface._layer)

    coords = get_triangulated(data(self._vertexes, surface._layer),self._vertexes,surface._layer)
    ref = self._refs[surface._layer]
    update_coords!(self._renderers.triangle,ref,coords)
end

# ! Must have
function destroy!(self::ParametricSurfaceRenderer)
end

# YELLOW Thread
Dependent2Observer(app::AppDNA,::ParametricSurfaceDependent)::ParametricSurfaceRenderer = getDependentObservers(app)[_SURFACES]

# ? ---------------------------------
# ! ParametricSurface
# ? ---------------------------------

# YELLOW Thread
function ParametricSurface(callback::Function,
                           uRange=range(0.0,1.0,50),vRange=range(0.0,1.0,50),
                           dependents::Vector{<:DependentDNA}=DependentDNA[],color_data::Union{Nothing,String}=nothing;
                           color="g")
    c = isnothing(color_data) ? get_color(color) : get_color(color_data)
    build!(ParametricSurfaceDependent(callback,dependents,uRange,vRange,c))
end

macro ParametricSurface(callback::Expr,uRange,vRange,args...)
    (positional_args, kw_args) = _parse_macro_arguments((:color_data,),(:color,), args...)
    callback = _validate_callback_expr(callback, 2)
    return _create_ctor_wrapper(callback, __module__, Juliagebra.ParametricSurface,
                                positional_args,kw_args,
                                (cb, deps) -> (cb, uRange, vRange, deps))
end

export ParametricSurface
export @ParametricSurface