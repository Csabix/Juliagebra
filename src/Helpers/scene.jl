struct _SceneMesh
    positions::Vector{Vec3F}
    normals::Vector{Vec3F}
    indices::Vector{UInt32}
end

Base.string(self::_SceneMesh)::String = return "Vertex count: $(length(self.positions)) Index count: $(length(self.indices))"
Base.show(io::IO, self::_SceneMesh) =  print(io, string(self))

struct SceneMesh
    _mesh::_SceneMesh
    _transform::Mat4x4T{Float32}
end

function get_positions(self::SceneMesh)
    M = self._transform
    return [let p = M * Vec4F(v.x, v.y, v.z, 1.0); Vec3F(p.x, p.y, p.z) end for v in self._mesh.positions]
end

function get_normals(self::SceneMesh)
    N_mat = transpose(inv(self._transform))
    return [let n = N_mat * Vec4F(v.x, v.y, v.z, 0.0); Vec3F(n.x, n.y, n.z) end for v in self._mesh.normals]
end

get_indices(self::SceneMesh) = self._mesh.indices

struct Scene
    transforms::Vector{Mat4x4T{Float32}}
    mesh_idx::Vector{UInt32}
    meshes::Vector{_SceneMesh}
end

Base.length(s::Scene) = length(s.mesh_idx)
Base.firstindex(s::Scene) = 1
Base.lastindex(s::Scene) = length(s.mesh_idx)

function Base.getindex(s::Scene, i::Int)
    return SceneMesh(s.meshes[s.mesh_idx[i]], s.transforms[i])
end

function Base.iterate(s::Scene, state=1)
    state > length(s) ? nothing : (s[state], state + 1)
end


function _load_mesh(mesh_ptr::Ptr{aiMesh})::_SceneMesh
    mesh::aiMesh = unsafe_load(mesh_ptr)::aiMesh

    pos_raw = unsafe_wrap(Array, mesh.mVertices, mesh.mNumVertices)
    positions = [Vec3F(v.x, v.y, v.z) for v in pos_raw]
    norm_raw = unsafe_wrap(Array, mesh.mNormals, mesh.mNumVertices)
    normals = [Vec3F(n.x, n.y, n.z) for n in norm_raw]
    indices = Vector{UInt32}()
    faces = unsafe_wrap(Array, mesh.mFaces, mesh.mNumFaces)
                
    for face in faces
        f_indices = unsafe_wrap(Array, face.mIndices, face.mNumIndices)
        append!(indices, f_indices)
    end

    return _SceneMesh(positions,normals,indices)
end

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
            push!(scene.transforms, transpose(Mat4x4T{Float32}(mat_array)))
            push!(scene.mesh_idx, assimp_mesh_idx+1)
        end
    end

    if node.mNumChildren > 0
        child_ptrs = unsafe_wrap(Array, node.mChildren, node.mNumChildren)
        for child_ptr in child_ptrs
            _get_scene_meshes(child_ptr, scene, transform[])
        end
    end
end


function load_scene(path::String;smooth_normals::Bool=true,scale_factor::Float32=1.0f0,drop_normals::Bool=false,z_up::Bool=false)::Scene
    components_to_remove =
        aiComponent_TANGENTS_AND_BITANGENTS |
        aiComponent_COLORS |
        aiComponent_TEXCOORDS |
        aiComponent_BONEWEIGHTS |
        aiComponent_ANIMATIONS |
        aiComponent_TEXTURES |
        aiComponent_LIGHTS |
        aiComponent_CAMERAS |
        aiComponent_MATERIALS |
        (drop_normals ? aiComponent_NORMALS : 0)

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
        aiProcess_FlipWindingOrder |
        (smooth_normals ? aiProcess_GenSmoothNormals : aiProcess_GenNormals)

    scene_ptr = aiImportFileExWithProperties(path, flags, C_NULL, props)
    aiReleasePropertyStore(props);

    my_scene = Scene([], [], [])
    if scene_ptr == C_NULL
        return my_scene
    end

    scene = unsafe_load(scene_ptr)
    for i in 1:scene.mNumMeshes
        mesh = unsafe_load(unsafe_load(scene.mMeshes, i))

        pos_raw = unsafe_wrap(Array, mesh.mVertices, mesh.mNumVertices)
        positions = [Vec3F(v.x, v.y, v.z) for v in pos_raw]
        norm_raw = unsafe_wrap(Array, mesh.mNormals, mesh.mNumVertices)
        normals = [Vec3F(n.x, n.y, n.z) for n in norm_raw]
        indices = Vector{UInt32}()
        faces = unsafe_wrap(Array, mesh.mFaces, mesh.mNumFaces)

        for face in faces
            f_indices = unsafe_wrap(Array, face.mIndices, face.mNumIndices)
            append!(indices, f_indices)
        end
        push!(my_scene.meshes, _SceneMesh(positions,normals,indices))
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
export SceneMesh
export load_scene