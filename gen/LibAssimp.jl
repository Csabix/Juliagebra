module LibAssimp

using assimp_jll
export assimp_jll

using CEnum: CEnum, @cenum

mutable struct aiFileIO end

# typedef void ( * aiLogStreamCallback ) ( const char * /* message */ , char * /* user */ )
const aiLogStreamCallback = Ptr{Cvoid}

struct aiLogStream
    callback::aiLogStreamCallback
    user::Ptr{Cchar}
end

struct aiPropertyStore
    sentinel::Cchar
end

const aiBool = Cint

function aiAttachLogStream(aiLogStream_)
    ccall((:aiAttachLogStream, libassimp), Cint, (Cint,), aiLogStream_)
end

function aiEnableVerboseLogging(d)
    ccall((:aiEnableVerboseLogging, libassimp), Cint, (aiBool,), d)
end

function aiDetachAllLogStreams()
    ccall((:aiDetachAllLogStreams, libassimp), Cint, ())
end

function aiReleaseImport(aiScene_)
    ccall((:aiReleaseImport, libassimp), Cint, (Cint,), aiScene_)
end

function aiGetErrorString()
    ccall((:aiGetErrorString, libassimp), Ptr{Cint}, ())
end

function aiGetExtensionList(aiString)
    ccall((:aiGetExtensionList, libassimp), Cint, (Cint,), aiString)
end

function aiGetMemoryRequirements(aiScene_)
    ccall((:aiGetMemoryRequirements, libassimp), Cint, (Cint,), aiScene_)
end

function aiReleasePropertyStore(aiPropertyStore_)
    ccall((:aiReleasePropertyStore, libassimp), Cint, (Cint,), aiPropertyStore_)
end

function aiSetImportPropertyInteger(aiPropertyStore_)
    ccall((:aiSetImportPropertyInteger, libassimp), Cint, (Cint,), aiPropertyStore_)
end

function aiSetImportPropertyFloat(aiPropertyStore_)
    ccall((:aiSetImportPropertyFloat, libassimp), Cint, (Cint,), aiPropertyStore_)
end

function aiSetImportPropertyString(aiPropertyStore_)
    ccall((:aiSetImportPropertyString, libassimp), Cint, (Cint,), aiPropertyStore_)
end

function aiSetImportPropertyMatrix(aiPropertyStore_)
    ccall((:aiSetImportPropertyMatrix, libassimp), Cint, (Cint,), aiPropertyStore_)
end

function aiCreateQuaternionFromMatrix(aiQuaternion)
    ccall((:aiCreateQuaternionFromMatrix, libassimp), Cint, (Cint,), aiQuaternion)
end

function aiDecomposeMatrix(aiMatrix4x4)
    ccall((:aiDecomposeMatrix, libassimp), Cint, (Cint,), aiMatrix4x4)
end

function aiTransposeMatrix4(aiMatrix4x4)
    ccall((:aiTransposeMatrix4, libassimp), Cint, (Cint,), aiMatrix4x4)
end

function aiTransposeMatrix3(aiMatrix3x3)
    ccall((:aiTransposeMatrix3, libassimp), Cint, (Cint,), aiMatrix3x3)
end

function aiTransformVecByMatrix3(aiVector3D)
    ccall((:aiTransformVecByMatrix3, libassimp), Cint, (Cint,), aiVector3D)
end

function aiTransformVecByMatrix4(aiVector3D)
    ccall((:aiTransformVecByMatrix4, libassimp), Cint, (Cint,), aiVector3D)
end

function aiMultiplyMatrix4(aiMatrix4x4)
    ccall((:aiMultiplyMatrix4, libassimp), Cint, (Cint,), aiMatrix4x4)
end

function aiMultiplyMatrix3(aiMatrix3x3)
    ccall((:aiMultiplyMatrix3, libassimp), Cint, (Cint,), aiMatrix3x3)
end

function aiIdentityMatrix3(aiMatrix3x3)
    ccall((:aiIdentityMatrix3, libassimp), Cint, (Cint,), aiMatrix3x3)
end

function aiIdentityMatrix4(aiMatrix4x4)
    ccall((:aiIdentityMatrix4, libassimp), Cint, (Cint,), aiMatrix4x4)
end

function aiVector2AreEqual(aiVector2D)
    ccall((:aiVector2AreEqual, libassimp), Cint, (Cint,), aiVector2D)
end

function aiVector2AreEqualEpsilon(aiVector2D)
    ccall((:aiVector2AreEqualEpsilon, libassimp), Cint, (Cint,), aiVector2D)
end

function aiVector2Add(aiVector2D)
    ccall((:aiVector2Add, libassimp), Cint, (Cint,), aiVector2D)
end

function aiVector2Subtract(aiVector2D)
    ccall((:aiVector2Subtract, libassimp), Cint, (Cint,), aiVector2D)
end

function aiVector2Scale(aiVector2D)
    ccall((:aiVector2Scale, libassimp), Cint, (Cint,), aiVector2D)
end

function aiVector2SymMul(aiVector2D)
    ccall((:aiVector2SymMul, libassimp), Cint, (Cint,), aiVector2D)
end

function aiVector2DivideByScalar(aiVector2D)
    ccall((:aiVector2DivideByScalar, libassimp), Cint, (Cint,), aiVector2D)
end

function aiVector2DivideByVector(aiVector2D)
    ccall((:aiVector2DivideByVector, libassimp), Cint, (Cint,), aiVector2D)
end

function aiVector2Length(aiVector2D)
    ccall((:aiVector2Length, libassimp), Cint, (Cint,), aiVector2D)
end

function aiVector2SquareLength(aiVector2D)
    ccall((:aiVector2SquareLength, libassimp), Cint, (Cint,), aiVector2D)
end

function aiVector2Negate(aiVector2D)
    ccall((:aiVector2Negate, libassimp), Cint, (Cint,), aiVector2D)
end

function aiVector2DotProduct(aiVector2D)
    ccall((:aiVector2DotProduct, libassimp), Cint, (Cint,), aiVector2D)
end

function aiVector2Normalize(aiVector2D)
    ccall((:aiVector2Normalize, libassimp), Cint, (Cint,), aiVector2D)
end

function aiVector3AreEqual(aiVector3D)
    ccall((:aiVector3AreEqual, libassimp), Cint, (Cint,), aiVector3D)
end

function aiVector3AreEqualEpsilon(aiVector3D)
    ccall((:aiVector3AreEqualEpsilon, libassimp), Cint, (Cint,), aiVector3D)
end

function aiVector3LessThan(aiVector3D)
    ccall((:aiVector3LessThan, libassimp), Cint, (Cint,), aiVector3D)
end

function aiVector3Add(aiVector3D)
    ccall((:aiVector3Add, libassimp), Cint, (Cint,), aiVector3D)
end

function aiVector3Subtract(aiVector3D)
    ccall((:aiVector3Subtract, libassimp), Cint, (Cint,), aiVector3D)
end

function aiVector3Scale(aiVector3D)
    ccall((:aiVector3Scale, libassimp), Cint, (Cint,), aiVector3D)
end

function aiVector3SymMul(aiVector3D)
    ccall((:aiVector3SymMul, libassimp), Cint, (Cint,), aiVector3D)
end

function aiVector3DivideByScalar(aiVector3D)
    ccall((:aiVector3DivideByScalar, libassimp), Cint, (Cint,), aiVector3D)
end

function aiVector3DivideByVector(aiVector3D)
    ccall((:aiVector3DivideByVector, libassimp), Cint, (Cint,), aiVector3D)
end

function aiVector3Length(aiVector3D)
    ccall((:aiVector3Length, libassimp), Cint, (Cint,), aiVector3D)
end

function aiVector3SquareLength(aiVector3D)
    ccall((:aiVector3SquareLength, libassimp), Cint, (Cint,), aiVector3D)
end

function aiVector3Negate(aiVector3D)
    ccall((:aiVector3Negate, libassimp), Cint, (Cint,), aiVector3D)
end

function aiVector3DotProduct(aiVector3D)
    ccall((:aiVector3DotProduct, libassimp), Cint, (Cint,), aiVector3D)
end

function aiVector3CrossProduct(aiVector3D)
    ccall((:aiVector3CrossProduct, libassimp), Cint, (Cint,), aiVector3D)
end

function aiVector3Normalize(aiVector3D)
    ccall((:aiVector3Normalize, libassimp), Cint, (Cint,), aiVector3D)
end

function aiVector3NormalizeSafe(aiVector3D)
    ccall((:aiVector3NormalizeSafe, libassimp), Cint, (Cint,), aiVector3D)
end

function aiVector3RotateByQuaternion(aiVector3D)
    ccall((:aiVector3RotateByQuaternion, libassimp), Cint, (Cint,), aiVector3D)
end

function aiMatrix3FromMatrix4(aiMatrix3x3)
    ccall((:aiMatrix3FromMatrix4, libassimp), Cint, (Cint,), aiMatrix3x3)
end

function aiMatrix3FromQuaternion(aiMatrix3x3)
    ccall((:aiMatrix3FromQuaternion, libassimp), Cint, (Cint,), aiMatrix3x3)
end

function aiMatrix3AreEqual(aiMatrix3x3)
    ccall((:aiMatrix3AreEqual, libassimp), Cint, (Cint,), aiMatrix3x3)
end

function aiMatrix3AreEqualEpsilon(aiMatrix3x3)
    ccall((:aiMatrix3AreEqualEpsilon, libassimp), Cint, (Cint,), aiMatrix3x3)
end

function aiMatrix3Inverse(aiMatrix3x3)
    ccall((:aiMatrix3Inverse, libassimp), Cint, (Cint,), aiMatrix3x3)
end

function aiMatrix3Determinant(aiMatrix3x3)
    ccall((:aiMatrix3Determinant, libassimp), Cint, (Cint,), aiMatrix3x3)
end

function aiMatrix3RotationZ(aiMatrix3x3)
    ccall((:aiMatrix3RotationZ, libassimp), Cint, (Cint,), aiMatrix3x3)
end

function aiMatrix3FromRotationAroundAxis(aiMatrix3x3)
    ccall((:aiMatrix3FromRotationAroundAxis, libassimp), Cint, (Cint,), aiMatrix3x3)
end

function aiMatrix3Translation(aiMatrix3x3)
    ccall((:aiMatrix3Translation, libassimp), Cint, (Cint,), aiMatrix3x3)
end

function aiMatrix3FromTo(aiMatrix3x3)
    ccall((:aiMatrix3FromTo, libassimp), Cint, (Cint,), aiMatrix3x3)
end

function aiMatrix4FromMatrix3(aiMatrix4x4)
    ccall((:aiMatrix4FromMatrix3, libassimp), Cint, (Cint,), aiMatrix4x4)
end

function aiMatrix4FromScalingQuaternionPosition(aiMatrix4x4)
    ccall((:aiMatrix4FromScalingQuaternionPosition, libassimp), Cint, (Cint,), aiMatrix4x4)
end

function aiMatrix4Add(aiMatrix4x4)
    ccall((:aiMatrix4Add, libassimp), Cint, (Cint,), aiMatrix4x4)
end

function aiMatrix4AreEqual(aiMatrix4x4)
    ccall((:aiMatrix4AreEqual, libassimp), Cint, (Cint,), aiMatrix4x4)
end

function aiMatrix4AreEqualEpsilon(aiMatrix4x4)
    ccall((:aiMatrix4AreEqualEpsilon, libassimp), Cint, (Cint,), aiMatrix4x4)
end

function aiMatrix4Inverse(aiMatrix4x4)
    ccall((:aiMatrix4Inverse, libassimp), Cint, (Cint,), aiMatrix4x4)
end

function aiMatrix4Determinant(aiMatrix4x4)
    ccall((:aiMatrix4Determinant, libassimp), Cint, (Cint,), aiMatrix4x4)
end

function aiMatrix4IsIdentity(aiMatrix4x4)
    ccall((:aiMatrix4IsIdentity, libassimp), Cint, (Cint,), aiMatrix4x4)
end

function aiMatrix4DecomposeIntoScalingEulerAnglesPosition(aiMatrix4x4)
    ccall((:aiMatrix4DecomposeIntoScalingEulerAnglesPosition, libassimp), Cint, (Cint,), aiMatrix4x4)
end

function aiMatrix4DecomposeIntoScalingAxisAnglePosition(aiMatrix4x4)
    ccall((:aiMatrix4DecomposeIntoScalingAxisAnglePosition, libassimp), Cint, (Cint,), aiMatrix4x4)
end

function aiMatrix4DecomposeNoScaling(aiMatrix4x4)
    ccall((:aiMatrix4DecomposeNoScaling, libassimp), Cint, (Cint,), aiMatrix4x4)
end

function aiMatrix4FromEulerAngles(aiMatrix4x4)
    ccall((:aiMatrix4FromEulerAngles, libassimp), Cint, (Cint,), aiMatrix4x4)
end

function aiMatrix4RotationX(aiMatrix4x4)
    ccall((:aiMatrix4RotationX, libassimp), Cint, (Cint,), aiMatrix4x4)
end

function aiMatrix4RotationY(aiMatrix4x4)
    ccall((:aiMatrix4RotationY, libassimp), Cint, (Cint,), aiMatrix4x4)
end

function aiMatrix4RotationZ(aiMatrix4x4)
    ccall((:aiMatrix4RotationZ, libassimp), Cint, (Cint,), aiMatrix4x4)
end

function aiMatrix4FromRotationAroundAxis(aiMatrix4x4)
    ccall((:aiMatrix4FromRotationAroundAxis, libassimp), Cint, (Cint,), aiMatrix4x4)
end

function aiMatrix4Translation(aiMatrix4x4)
    ccall((:aiMatrix4Translation, libassimp), Cint, (Cint,), aiMatrix4x4)
end

function aiMatrix4Scaling(aiMatrix4x4)
    ccall((:aiMatrix4Scaling, libassimp), Cint, (Cint,), aiMatrix4x4)
end

function aiMatrix4FromTo(aiMatrix4x4)
    ccall((:aiMatrix4FromTo, libassimp), Cint, (Cint,), aiMatrix4x4)
end

function aiQuaternionFromEulerAngles(aiQuaternion)
    ccall((:aiQuaternionFromEulerAngles, libassimp), Cint, (Cint,), aiQuaternion)
end

function aiQuaternionFromAxisAngle(aiQuaternion)
    ccall((:aiQuaternionFromAxisAngle, libassimp), Cint, (Cint,), aiQuaternion)
end

function aiQuaternionFromNormalizedQuaternion(aiQuaternion)
    ccall((:aiQuaternionFromNormalizedQuaternion, libassimp), Cint, (Cint,), aiQuaternion)
end

function aiQuaternionAreEqual(aiQuaternion)
    ccall((:aiQuaternionAreEqual, libassimp), Cint, (Cint,), aiQuaternion)
end

function aiQuaternionAreEqualEpsilon(aiQuaternion)
    ccall((:aiQuaternionAreEqualEpsilon, libassimp), Cint, (Cint,), aiQuaternion)
end

function aiQuaternionNormalize(aiQuaternion)
    ccall((:aiQuaternionNormalize, libassimp), Cint, (Cint,), aiQuaternion)
end

function aiQuaternionConjugate(aiQuaternion)
    ccall((:aiQuaternionConjugate, libassimp), Cint, (Cint,), aiQuaternion)
end

function aiQuaternionMultiply(aiQuaternion)
    ccall((:aiQuaternionMultiply, libassimp), Cint, (Cint,), aiQuaternion)
end

function aiQuaternionInterpolate(aiQuaternion)
    ccall((:aiQuaternionInterpolate, libassimp), Cint, (Cint,), aiQuaternion)
end

mutable struct ASSIMP_API end

struct aiScene
    mFlags::Cuint
    aiNode::Cint
    mNumMeshes::Cuint
    aiMesh::Cint
    mNumMaterials::Cuint
    aiMaterial::Cint
    mNumAnimations::Cuint
    aiAnimation::Cint
    mNumTextures::Cuint
    aiTexture::Cint
    mNumLights::Cuint
    aiLight::Cint
    mNumCameras::Cuint
    aiCamera::Cint
    aiMetadata::Cint
    aiString::Cint
    mNumSkeletons::Cuint
    aiSkeleton::Cint
    mPrivate::Ptr{Cchar}
end

@cenum aiPostProcessSteps::UInt32 begin
    aiProcess_CalcTangentSpace = 1
    aiProcess_JoinIdenticalVertices = 2
    aiProcess_MakeLeftHanded = 4
    aiProcess_Triangulate = 8
    aiProcess_RemoveComponent = 16
    aiProcess_GenNormals = 32
    aiProcess_GenSmoothNormals = 64
    aiProcess_SplitLargeMeshes = 128
    aiProcess_PreTransformVertices = 256
    aiProcess_LimitBoneWeights = 512
    aiProcess_ValidateDataStructure = 1024
    aiProcess_ImproveCacheLocality = 2048
    aiProcess_RemoveRedundantMaterials = 4096
    aiProcess_FixInfacingNormals = 8192
    aiProcess_PopulateArmatureData = 16384
    aiProcess_SortByPType = 32768
    aiProcess_FindDegenerates = 65536
    aiProcess_FindInvalidData = 131072
    aiProcess_GenUVCoords = 262144
    aiProcess_TransformUVCoords = 524288
    aiProcess_FindInstances = 1048576
    aiProcess_OptimizeMeshes = 2097152
    aiProcess_OptimizeGraph = 4194304
    aiProcess_FlipUVs = 8388608
    aiProcess_FlipWindingOrder = 16777216
    aiProcess_SplitByBoneCount = 33554432
    aiProcess_Debone = 67108864
    aiProcess_GlobalScale = 134217728
    aiProcess_EmbedTextures = 268435456
    aiProcess_ForceGenNormals = 536870912
    aiProcess_DropNormals = 1073741824
    aiProcess_GenBoundingBoxes = 0x0000000080000000
end

@cenum aiComponent::UInt32 begin
    aiComponent_NORMALS = 2
    aiComponent_TANGENTS_AND_BITANGENTS = 4
    aiComponent_COLORS = 8
    aiComponent_TEXCOORDS = 16
    aiComponent_BONEWEIGHTS = 32
    aiComponent_ANIMATIONS = 64
    aiComponent_TEXTURES = 128
    aiComponent_LIGHTS = 256
    aiComponent_CAMERAS = 512
    aiComponent_MESHES = 1024
    aiComponent_MATERIALS = 2048
    _aiComponent_Force32Bit = 0x000000009fffffff
end

const AI_FALSE = 0

const AI_TRUE = 1

const AI_SCENE_FLAGS_INCOMPLETE = 0x01

const AI_SCENE_FLAGS_VALIDATED = 0x02

const AI_SCENE_FLAGS_VALIDATION_WARNING = 0x04

const AI_SCENE_FLAGS_NON_VERBOSE_FORMAT = 0x08

const AI_SCENE_FLAGS_TERRAIN = 0x10

const AI_SCENE_FLAGS_ALLOW_SHARED = 0x20

const aiProcess_ConvertToLeftHanded = ((aiProcess_MakeLeftHanded | aiProcess_FlipUVs) | aiProcess_FlipWindingOrder) | 0

const aiProcessPreset_TargetRealtime_Fast = (((((aiProcess_CalcTangentSpace | aiProcess_GenNormals) | aiProcess_JoinIdenticalVertices) | aiProcess_Triangulate) | aiProcess_GenUVCoords) | aiProcess_SortByPType) | 0

const aiProcessPreset_TargetRealtime_Quality = (((((((((((aiProcess_CalcTangentSpace | aiProcess_GenSmoothNormals) | aiProcess_JoinIdenticalVertices) | aiProcess_ImproveCacheLocality) | aiProcess_LimitBoneWeights) | aiProcess_RemoveRedundantMaterials) | aiProcess_SplitLargeMeshes) | aiProcess_Triangulate) | aiProcess_GenUVCoords) | aiProcess_SortByPType) | aiProcess_FindDegenerates) | aiProcess_FindInvalidData) | 0

const aiProcessPreset_TargetRealtime_MaxQuality = (((aiProcessPreset_TargetRealtime_Quality | aiProcess_FindInstances) | aiProcess_ValidateDataStructure) | aiProcess_OptimizeMeshes) | 0

const AI_CONFIG_GLOB_MEASURE_TIME = "GLOB_MEASURE_TIME"

const AI_CONFIG_IMPORT_NO_SKELETON_MESHES = "IMPORT_NO_SKELETON_MESHES"

const AI_CONFIG_PP_SBBC_MAX_BONES = "PP_SBBC_MAX_BONES"

const AI_SBBC_DEFAULT_MAX_BONES = 60

const AI_CONFIG_PP_CT_MAX_SMOOTHING_ANGLE = "PP_CT_MAX_SMOOTHING_ANGLE"

const AI_CONFIG_PP_CT_TEXTURE_CHANNEL_INDEX = "PP_CT_TEXTURE_CHANNEL_INDEX"

const AI_CONFIG_PP_GSN_MAX_SMOOTHING_ANGLE = "PP_GSN_MAX_SMOOTHING_ANGLE"

const AI_CONFIG_IMPORT_MDL_COLORMAP = "IMPORT_MDL_COLORMAP"

const AI_CONFIG_PP_RRM_EXCLUDE_LIST = "PP_RRM_EXCLUDE_LIST"

const AI_CONFIG_PP_PTV_KEEP_HIERARCHY = "PP_PTV_KEEP_HIERARCHY"

const AI_CONFIG_PP_PTV_NORMALIZE = "PP_PTV_NORMALIZE"

const AI_CONFIG_PP_PTV_ADD_ROOT_TRANSFORMATION = "PP_PTV_ADD_ROOT_TRANSFORMATION"

const AI_CONFIG_PP_PTV_ROOT_TRANSFORMATION = "PP_PTV_ROOT_TRANSFORMATION"

const AI_CONFIG_PP_FD_REMOVE = "PP_FD_REMOVE"

const AI_CONFIG_PP_FD_CHECKAREA = "PP_FD_CHECKAREA"

const AI_CONFIG_PP_OG_EXCLUDE_LIST = "PP_OG_EXCLUDE_LIST"

const AI_CONFIG_PP_SLM_TRIANGLE_LIMIT = "PP_SLM_TRIANGLE_LIMIT"

const AI_SLM_DEFAULT_MAX_TRIANGLES = 1000000

const AI_CONFIG_PP_SLM_VERTEX_LIMIT = "PP_SLM_VERTEX_LIMIT"

const AI_SLM_DEFAULT_MAX_VERTICES = 1000000

const AI_CONFIG_PP_LBW_MAX_WEIGHTS = "PP_LBW_MAX_WEIGHTS"

const AI_LMW_MAX_WEIGHTS = 0x04

const AI_CONFIG_PP_DB_THRESHOLD = "PP_DB_THRESHOLD"

const AI_DEBONE_THRESHOLD = Float32(1.0)

const AI_CONFIG_PP_DB_ALL_OR_NONE = "PP_DB_ALL_OR_NONE"

const PP_ICL_PTCACHE_SIZE = 12

const AI_CONFIG_PP_ICL_PTCACHE_SIZE = "PP_ICL_PTCACHE_SIZE"

const AI_CONFIG_PP_RVC_FLAGS = "PP_RVC_FLAGS"

const AI_CONFIG_PP_SBP_REMOVE = "PP_SBP_REMOVE"

const AI_CONFIG_PP_FID_ANIM_ACCURACY = "PP_FID_ANIM_ACCURACY"

const AI_CONFIG_PP_FID_IGNORE_TEXTURECOORDS = "PP_FID_IGNORE_TEXTURECOORDS"

const AI_UVTRAFO_SCALING = 0x01

const AI_UVTRAFO_ROTATION = 0x02

const AI_UVTRAFO_TRANSLATION = 0x04

const AI_UVTRAFO_ALL = (AI_UVTRAFO_SCALING | AI_UVTRAFO_ROTATION) | AI_UVTRAFO_TRANSLATION

const AI_CONFIG_PP_TUV_EVALUATE = "PP_TUV_EVALUATE"

const AI_CONFIG_FAVOUR_SPEED = "FAVOUR_SPEED"

const AI_CONFIG_IMPORT_SCHEMA_DOCUMENT_PROVIDER = "IMPORT_SCHEMA_DOCUMENT_PROVIDER"

const AI_CONFIG_IMPORT_FBX_READ_ALL_GEOMETRY_LAYERS = "IMPORT_FBX_READ_ALL_GEOMETRY_LAYERS"

const AI_CONFIG_IMPORT_FBX_READ_ALL_MATERIALS = "IMPORT_FBX_READ_ALL_MATERIALS"

const AI_CONFIG_IMPORT_FBX_READ_MATERIALS = "IMPORT_FBX_READ_MATERIALS"

const AI_CONFIG_IMPORT_FBX_READ_TEXTURES = "IMPORT_FBX_READ_TEXTURES"

const AI_CONFIG_IMPORT_FBX_READ_CAMERAS = "IMPORT_FBX_READ_CAMERAS"

const AI_CONFIG_IMPORT_FBX_READ_LIGHTS = "IMPORT_FBX_READ_LIGHTS"

const AI_CONFIG_IMPORT_FBX_READ_ANIMATIONS = "IMPORT_FBX_READ_ANIMATIONS"

const AI_CONFIG_IMPORT_FBX_READ_WEIGHTS = "IMPORT_FBX_READ_WEIGHTS"

const AI_CONFIG_IMPORT_FBX_STRICT_MODE = "IMPORT_FBX_STRICT_MODE"

const AI_CONFIG_IMPORT_FBX_PRESERVE_PIVOTS = "IMPORT_FBX_PRESERVE_PIVOTS"

const AI_CONFIG_IMPORT_FBX_OPTIMIZE_EMPTY_ANIMATION_CURVES = "IMPORT_FBX_OPTIMIZE_EMPTY_ANIMATION_CURVES"

const AI_CONFIG_IMPORT_FBX_EMBEDDED_TEXTURES_LEGACY_NAMING = "AI_CONFIG_IMPORT_FBX_EMBEDDED_TEXTURES_LEGACY_NAMING"

const AI_CONFIG_IMPORT_REMOVE_EMPTY_BONES = "AI_CONFIG_IMPORT_REMOVE_EMPTY_BONES"

const AI_CONFIG_FBX_CONVERT_TO_M = "AI_CONFIG_FBX_CONVERT_TO_M"

const AI_CONFIG_FBX_USE_SKELETON_BONE_CONTAINER = "AI_CONFIG_FBX_USE_SKELETON_BONE_CONTAINER"

const AI_CONFIG_IMPORT_GLOBAL_KEYFRAME = "IMPORT_GLOBAL_KEYFRAME"

const AI_CONFIG_IMPORT_MD3_KEYFRAME = "IMPORT_MD3_KEYFRAME"

const AI_CONFIG_IMPORT_MD2_KEYFRAME = "IMPORT_MD2_KEYFRAME"

const AI_CONFIG_IMPORT_MDL_KEYFRAME = "IMPORT_MDL_KEYFRAME"

const AI_CONFIG_IMPORT_MDC_KEYFRAME = "IMPORT_MDC_KEYFRAME"

const AI_CONFIG_IMPORT_SMD_KEYFRAME = "IMPORT_SMD_KEYFRAME"

const AI_CONFIG_IMPORT_UNREAL_KEYFRAME = "IMPORT_UNREAL_KEYFRAME"

const AI_CONFIG_IMPORT_MDL_HL1_READ_ANIMATIONS = "IMPORT_MDL_HL1_READ_ANIMATIONS"

const AI_CONFIG_IMPORT_MDL_HL1_READ_ANIMATION_EVENTS = "IMPORT_MDL_HL1_READ_ANIMATION_EVENTS"

const AI_CONFIG_IMPORT_MDL_HL1_READ_BLEND_CONTROLLERS = "IMPORT_MDL_HL1_READ_BLEND_CONTROLLERS"

const AI_CONFIG_IMPORT_MDL_HL1_READ_SEQUENCE_TRANSITIONS = "IMPORT_MDL_HL1_READ_SEQUENCE_TRANSITIONS"

const AI_CONFIG_IMPORT_MDL_HL1_READ_ATTACHMENTS = "IMPORT_MDL_HL1_READ_ATTACHMENTS"

const AI_CONFIG_IMPORT_MDL_HL1_READ_BONE_CONTROLLERS = "IMPORT_MDL_HL1_READ_BONE_CONTROLLERS"

const AI_CONFIG_IMPORT_MDL_HL1_READ_HITBOXES = "IMPORT_MDL_HL1_READ_HITBOXES"

const AI_CONFIG_IMPORT_MDL_HL1_READ_MISC_GLOBAL_INFO = "IMPORT_MDL_HL1_READ_MISC_GLOBAL_INFO"

const AI_CONFIG_IMPORT_SMD_LOAD_ANIMATION_LIST = "IMPORT_SMD_LOAD_ANIMATION_LIST"

const AI_CONFIG_IMPORT_AC_SEPARATE_BFCULL = "IMPORT_AC_SEPARATE_BFCULL"

const AI_CONFIG_IMPORT_AC_EVAL_SUBDIVISION = "IMPORT_AC_EVAL_SUBDIVISION"

const AI_CONFIG_IMPORT_UNREAL_HANDLE_FLAGS = "UNREAL_HANDLE_FLAGS"

const AI_CONFIG_IMPORT_TER_MAKE_UVS = "IMPORT_TER_MAKE_UVS"

const AI_CONFIG_IMPORT_ASE_RECONSTRUCT_NORMALS = "IMPORT_ASE_RECONSTRUCT_NORMALS"

const AI_CONFIG_IMPORT_MD3_HANDLE_MULTIPART = "IMPORT_MD3_HANDLE_MULTIPART"

const AI_CONFIG_IMPORT_MD3_SKIN_NAME = "IMPORT_MD3_SKIN_NAME"

const AI_CONFIG_IMPORT_MD3_LOAD_SHADERS = "IMPORT_MD3_LOAD_SHADERS"

const AI_CONFIG_IMPORT_MD3_SHADER_SRC = "IMPORT_MD3_SHADER_SRC"

const AI_CONFIG_IMPORT_LWO_ONE_LAYER_ONLY = "IMPORT_LWO_ONE_LAYER_ONLY"

const AI_CONFIG_IMPORT_MD5_NO_ANIM_AUTOLOAD = "IMPORT_MD5_NO_ANIM_AUTOLOAD"

const AI_CONFIG_IMPORT_LWS_ANIM_START = "IMPORT_LWS_ANIM_START"

const AI_CONFIG_IMPORT_LWS_ANIM_END = "IMPORT_LWS_ANIM_END"

const AI_CONFIG_IMPORT_IRR_ANIM_FPS = "IMPORT_IRR_ANIM_FPS"

const AI_CONFIG_IMPORT_OGRE_MATERIAL_FILE = "IMPORT_OGRE_MATERIAL_FILE"

const AI_CONFIG_IMPORT_OGRE_TEXTURETYPE_FROM_FILENAME = "IMPORT_OGRE_TEXTURETYPE_FROM_FILENAME"

const AI_CONFIG_ANDROID_JNI_ASSIMP_MANAGER_SUPPORT = "AI_CONFIG_ANDROID_JNI_ASSIMP_MANAGER_SUPPORT"

const AI_CONFIG_IMPORT_IFC_SKIP_SPACE_REPRESENTATIONS = "IMPORT_IFC_SKIP_SPACE_REPRESENTATIONS"

const AI_CONFIG_IMPORT_IFC_CUSTOM_TRIANGULATION = "IMPORT_IFC_CUSTOM_TRIANGULATION"

const AI_CONFIG_IMPORT_IFC_SMOOTHING_ANGLE = "IMPORT_IFC_SMOOTHING_ANGLE"

const AI_IMPORT_IFC_DEFAULT_SMOOTHING_ANGLE = Float32(10.0)

const AI_CONFIG_IMPORT_IFC_CYLINDRICAL_TESSELLATION = "IMPORT_IFC_CYLINDRICAL_TESSELLATION"

const AI_IMPORT_IFC_DEFAULT_CYLINDRICAL_TESSELLATION = 32

const AI_CONFIG_IMPORT_COLLADA_IGNORE_UP_DIRECTION = "IMPORT_COLLADA_IGNORE_UP_DIRECTION"

const AI_CONFIG_IMPORT_COLLADA_USE_COLLADA_NAMES = "IMPORT_COLLADA_USE_COLLADA_NAMES"

const AI_CONFIG_EXPORT_XFILE_64BIT = "EXPORT_XFILE_64BIT"

const AI_CONFIG_EXPORT_POINT_CLOUDS = "EXPORT_POINT_CLOUDS"

const AI_CONFIG_EXPORT_BLOB_NAME = "EXPORT_BLOB_NAME"

const AI_CONFIG_GLOBAL_SCALE_FACTOR_KEY = "GLOBAL_SCALE_FACTOR"

const AI_CONFIG_GLOBAL_SCALE_FACTOR_DEFAULT = Float32(1.0)

const AI_CONFIG_APP_SCALE_KEY = "APP_SCALE_FACTOR"

# exports
const PREFIXES = ["ai", "AI"]
for name in names(@__MODULE__; all=true), prefix in PREFIXES
    if startswith(string(name), prefix)
        @eval export $name
    end
end

end # module
