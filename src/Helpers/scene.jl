struct Mesh
    positions::Vector{Vec3D}
    indices::Union{Nothing,Vector{UInt32}}
end

get_positions(self::Mesh)::Vector{Vec3D} = copy(self.positions)
get_indices(self::Mesh)::Union{Nothing,Vector{UInt32}} = isnothing(self.indices) ? nothing : copy(self.indices)

Base.string(self::Mesh)::String = return "Vertex count: $(length(self.positions))"
Base.show(io::IO, self::Mesh) =  print(io, string(self))

struct MeshProxy
    _mesh::Mesh
    _transform::Mat4x4T{Float64}
end

function get_positions(self::MeshProxy)::Vector{Vec3D}
    M = self._transform
    return [let p = M * Vec4D(v.x, v.y, v.z, 1.0); Vec3D(p.x, p.y, p.z) end for v in self._mesh.positions]
end
get_indices(self::MeshProxy) = get_indices(self._mesh)

struct Scene
    mesh_instances::Vector{MeshProxy}
    base_meshes::Vector{Mesh}
end

@inline Base.length(s::Scene) = length(s.mesh_instances)
@inline Base.firstindex(s::Scene) = 1
@inline Base.lastindex(s::Scene) = length(s.mesh_instances)

@inline Base.getindex(s::Scene, i::Int) = s.mesh_instances[i]
@inline Base.iterate(s::Scene, state::Int=1) = state > length(s) ? nothing : (s[state], state + 1)

function _get_scene_meshes(
    node_ptr::Ptr{aiNode},
    scene::Scene,
    accTransform::aiMatrix4x4)

    node::aiNode = unsafe_load(node_ptr)::aiNode

    transform = Ref(deepcopy(accTransform))
    aiMultiplyMatrix4(transform,Ref(node.mTransformation))

    if node.mNumMeshes > 0
        mesh_indices = unsafe_wrap(Array, node.mMeshes, node.mNumMeshes)

        for assimp_mesh_idx in mesh_indices
            mat_array = reinterpret(Float32, [transform[]])
            push!(scene.mesh_instances, MeshProxy(scene.base_meshes[assimp_mesh_idx+1],transpose(Mat4x4T{Float64}(mat_array))))
        end
    end

    if node.mNumChildren > 0
        child_ptrs = unsafe_wrap(Array, node.mChildren, node.mNumChildren)
        for child_ptr in child_ptrs
            _get_scene_meshes(child_ptr, scene, transform[])
        end
    end
end


function load_scene(path::String;scale_factor::Float32=1.0f0,z_up::Bool=false)::Scene
    components_to_remove =
        aiComponent_NORMALS |
        aiComponent_TANGENTS_AND_BITANGENTS |
        aiComponent_COLORS |
        aiComponent_TEXCOORDS |
        aiComponent_BONEWEIGHTS |
        aiComponent_ANIMATIONS |
        aiComponent_TEXTURES |
        aiComponent_LIGHTS |
        aiComponent_CAMERAS |
        aiComponent_MATERIALS

    props = aiCreatePropertyStore()

    aiSetImportPropertyInteger(props, AI_CONFIG_PP_RVC_FLAGS, components_to_remove)
    aiSetImportPropertyFloat(props, AI_CONFIG_GLOBAL_SCALE_FACTOR_KEY, scale_factor)
    aiSetImportPropertyInteger(props, AI_CONFIG_IMPORT_FBX_PRESERVE_PIVOTS, 0)

    flags =
        aiProcess_JoinIdenticalVertices |
        aiProcess_Triangulate |
        aiProcess_RemoveComponent |
        aiProcess_ImproveCacheLocality |
        aiProcess_FindInvalidData |
        aiProcess_GlobalScale |
        aiProcess_FlipWindingOrder

    scene_ptr = aiImportFileExWithProperties(path, flags, C_NULL, props)
    aiReleasePropertyStore(props);

    my_scene = Scene([], [])
    if scene_ptr == C_NULL
        return my_scene
    end

    scene = unsafe_load(scene_ptr)
    for i in 1:scene.mNumMeshes
        mesh = unsafe_load(unsafe_load(scene.mMeshes, i))

        pos_raw = unsafe_wrap(Array, mesh.mVertices, mesh.mNumVertices)
        positions = [Vec3D(v.x, v.y, v.z) for v in pos_raw]
        indices = Vector{UInt32}()
        faces = unsafe_wrap(Array, mesh.mFaces, mesh.mNumFaces)

        for face in faces
            f_indices = unsafe_wrap(Array, face.mIndices, face.mNumIndices)
            append!(indices, f_indices)
        end
        push!(my_scene.base_meshes, Mesh(positions,indices))
    end

    root_transform = z_up ?
        aiMatrix4x4(
            1.0, 0.0, 0.0, 0.0,
            0.0, 1.0, 0.0, 0.0,
            0.0, 0.0, 1.0, 0.0,
            0.0, 0.0, 0.0, 1.0
        ) :
        aiMatrix4x4(
            1.0, 0.0, 0.0, 0.0,
            0.0, 0.0,-1.0, 0.0,
            0.0, 1.0, 0.0, 0.0,
            0.0, 0.0, 0.0, 1.0
        )

    _get_scene_meshes(unsafe_load(scene_ptr).mRootNode, my_scene, root_transform)

    aiReleaseImport(scene_ptr)
    return my_scene
end

export Scene
export Mesh
export MeshProxy
export load_scene