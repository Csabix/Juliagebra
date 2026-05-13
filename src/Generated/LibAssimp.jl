using assimp_jll

using CEnum: CEnum, @cenum

const ai_real = Cfloat

const ai_int = Cint

const ai_uint = Cuint

struct aiVector2D
    x::ai_real
    y::ai_real
end

struct aiVector3D
    x::ai_real
    y::ai_real
    z::ai_real
end

struct aiColor4D
    r::ai_real
    g::ai_real
    b::ai_real
    a::ai_real
end

struct aiMatrix3x3
    a1::ai_real
    a2::ai_real
    a3::ai_real
    b1::ai_real
    b2::ai_real
    b3::ai_real
    c1::ai_real
    c2::ai_real
    c3::ai_real
end

struct aiMatrix4x4
    a1::ai_real
    a2::ai_real
    a3::ai_real
    a4::ai_real
    b1::ai_real
    b2::ai_real
    b3::ai_real
    b4::ai_real
    c1::ai_real
    c2::ai_real
    c3::ai_real
    c4::ai_real
    d1::ai_real
    d2::ai_real
    d3::ai_real
    d4::ai_real
end

struct aiQuaternion
    w::ai_real
    x::ai_real
    y::ai_real
    z::ai_real
end

const ai_int32 = Int32

const ai_uint32 = UInt32

struct aiPlane
    a::ai_real
    b::ai_real
    c::ai_real
    d::ai_real
end

struct aiRay
    pos::aiVector3D
    dir::aiVector3D
end

struct aiColor3D
    r::ai_real
    g::ai_real
    b::ai_real
end

struct aiString
    length::ai_uint32
    data::NTuple{1024, Cchar}
end

@cenum aiReturn::Int32 begin
    aiReturn_SUCCESS = 0
    aiReturn_FAILURE = -1
    aiReturn_OUTOFMEMORY = -3
    _AI_ENFORCE_ENUM_SIZE = 2147483647
end

@cenum aiOrigin::UInt32 begin
    aiOrigin_SET = 0
    aiOrigin_CUR = 1
    aiOrigin_END = 2
    _AI_ORIGIN_ENFORCE_ENUM_SIZE = 2147483647
end

@cenum aiDefaultLogStream::UInt32 begin
    aiDefaultLogStream_FILE = 1
    aiDefaultLogStream_STDOUT = 2
    aiDefaultLogStream_STDERR = 4
    aiDefaultLogStream_DEBUGGER = 8
    _AI_DLS_ENFORCE_ENUM_SIZE = 2147483647
end

struct aiMemoryInfo
    textures::Cuint
    materials::Cuint
    meshes::Cuint
    nodes::Cuint
    animations::Cuint
    cameras::Cuint
    lights::Cuint
    total::Cuint
end

# typedef size_t ( * aiFileWriteProc ) ( C_STRUCT aiFile * , const char * , size_t , size_t )
const aiFileWriteProc = Ptr{Cvoid}

# typedef size_t ( * aiFileReadProc ) ( C_STRUCT aiFile * , char * , size_t , size_t )
const aiFileReadProc = Ptr{Cvoid}

# typedef size_t ( * aiFileTellProc ) ( C_STRUCT aiFile * )
const aiFileTellProc = Ptr{Cvoid}

# typedef void ( * aiFileFlushProc ) ( C_STRUCT aiFile * )
const aiFileFlushProc = Ptr{Cvoid}

# typedef C_ENUM aiReturn ( * aiFileSeek ) ( C_STRUCT aiFile * , size_t , C_ENUM aiOrigin )
const aiFileSeek = Ptr{Cvoid}

# typedef C_STRUCT aiFile * ( * aiFileOpenProc ) ( C_STRUCT aiFileIO * , const char * , const char * )
const aiFileOpenProc = Ptr{Cvoid}

# typedef void ( * aiFileCloseProc ) ( C_STRUCT aiFileIO * , C_STRUCT aiFile * )
const aiFileCloseProc = Ptr{Cvoid}

const aiUserData = Ptr{Cchar}

struct aiFileIO
    OpenProc::aiFileOpenProc
    CloseProc::aiFileCloseProc
    UserData::aiUserData
end

struct aiFile
    ReadProc::aiFileReadProc
    WriteProc::aiFileWriteProc
    TellProc::aiFileTellProc
    FileSizeProc::aiFileTellProc
    SeekProc::aiFileSeek
    FlushProc::aiFileFlushProc
    UserData::aiUserData
end

@cenum aiImporterFlags::UInt32 begin
    aiImporterFlags_SupportTextFlavour = 1
    aiImporterFlags_SupportBinaryFlavour = 2
    aiImporterFlags_SupportCompressedFlavour = 4
    aiImporterFlags_LimitedSupport = 8
    aiImporterFlags_Experimental = 16
end

struct aiImporterDesc
    mName::Ptr{Cchar}
    mAuthor::Ptr{Cchar}
    mMaintainer::Ptr{Cchar}
    mComments::Ptr{Cchar}
    mFlags::Cuint
    mMinMajor::Cuint
    mMinMinor::Cuint
    mMaxMajor::Cuint
    mMaxMinor::Cuint
    mFileExtensions::Ptr{Cchar}
end

function aiGetImporterDesc(extension)
    ccall((:aiGetImporterDesc, libassimp), Ptr{aiImporterDesc}, (Ptr{Cchar},), extension)
end

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

@cenum aiMetadataType::UInt32 begin
    AI_BOOL = 0
    AI_INT32 = 1
    AI_UINT64 = 2
    AI_FLOAT = 3
    AI_DOUBLE = 4
    AI_AISTRING = 5
    AI_AIVECTOR3D = 6
    AI_AIMETADATA = 7
    AI_META_MAX = 8
    FORCE_32BIT = 2147483647
end

struct aiMetadataEntry
    mType::aiMetadataType
    mData::Ptr{Cvoid}
end

struct aiMetadata
    mNumProperties::Cuint
    mKeys::Ptr{aiString}
    mValues::Ptr{aiMetadataEntry}
end

struct aiNode
    mName::aiString
    mTransformation::aiMatrix4x4
    mParent::Ptr{aiNode}
    mNumChildren::Cuint
    mChildren::Ptr{Ptr{aiNode}}
    mNumMeshes::Cuint
    mMeshes::Ptr{Cuint}
    mMetaData::Ptr{aiMetadata}
end

struct aiFace
    mNumIndices::Cuint
    mIndices::Ptr{Cuint}
end

struct aiVertexWeight
    mVertexId::Cuint
    mWeight::ai_real
end

struct aiBone
    mName::aiString
    mNumWeights::Cuint
    mArmature::Ptr{aiNode}
    mNode::Ptr{aiNode}
    mWeights::Ptr{aiVertexWeight}
    mOffsetMatrix::aiMatrix4x4
end

struct aiAnimMesh
    mName::aiString
    mVertices::Ptr{aiVector3D}
    mNormals::Ptr{aiVector3D}
    mTangents::Ptr{aiVector3D}
    mBitangents::Ptr{aiVector3D}
    mColors::NTuple{8, Ptr{aiColor4D}}
    mTextureCoords::NTuple{8, Ptr{aiVector3D}}
    mNumVertices::Cuint
    mWeight::Cfloat
end

struct aiAABB
    mMin::aiVector3D
    mMax::aiVector3D
end

struct aiMesh
    mPrimitiveTypes::Cuint
    mNumVertices::Cuint
    mNumFaces::Cuint
    mVertices::Ptr{aiVector3D}
    mNormals::Ptr{aiVector3D}
    mTangents::Ptr{aiVector3D}
    mBitangents::Ptr{aiVector3D}
    mColors::NTuple{8, Ptr{aiColor4D}}
    mTextureCoords::NTuple{8, Ptr{aiVector3D}}
    mNumUVComponents::NTuple{8, Cuint}
    mFaces::Ptr{aiFace}
    mNumBones::Cuint
    mBones::Ptr{Ptr{aiBone}}
    mMaterialIndex::Cuint
    mName::aiString
    mNumAnimMeshes::Cuint
    mAnimMeshes::Ptr{Ptr{aiAnimMesh}}
    mMethod::Cuint
    mAABB::aiAABB
    mTextureCoordsNames::Ptr{Ptr{aiString}}
end

@cenum aiPropertyTypeInfo::UInt32 begin
    aiPTI_Float = 1
    aiPTI_Double = 2
    aiPTI_String = 3
    aiPTI_Integer = 4
    aiPTI_Buffer = 5
    _aiPTI_Force32Bit = 2147483647
end

struct aiMaterialProperty
    mKey::aiString
    mSemantic::Cuint
    mIndex::Cuint
    mDataLength::Cuint
    mType::aiPropertyTypeInfo
    mData::Ptr{Cchar}
end

struct aiMaterial
    mProperties::Ptr{Ptr{aiMaterialProperty}}
    mNumProperties::Cuint
    mNumAllocated::Cuint
end

struct aiVectorKey
    mTime::Cdouble
    mValue::aiVector3D
end

struct aiQuatKey
    mTime::Cdouble
    mValue::aiQuaternion
end

@cenum aiAnimBehaviour::UInt32 begin
    aiAnimBehaviour_DEFAULT = 0
    aiAnimBehaviour_CONSTANT = 1
    aiAnimBehaviour_LINEAR = 2
    aiAnimBehaviour_REPEAT = 3
    _aiAnimBehaviour_Force32Bit = 2147483647
end

struct aiNodeAnim
    mNodeName::aiString
    mNumPositionKeys::Cuint
    mPositionKeys::Ptr{aiVectorKey}
    mNumRotationKeys::Cuint
    mRotationKeys::Ptr{aiQuatKey}
    mNumScalingKeys::Cuint
    mScalingKeys::Ptr{aiVectorKey}
    mPreState::aiAnimBehaviour
    mPostState::aiAnimBehaviour
end

struct aiMeshKey
    mTime::Cdouble
    mValue::Cuint
end

struct aiMeshAnim
    mName::aiString
    mNumKeys::Cuint
    mKeys::Ptr{aiMeshKey}
end

struct aiMeshMorphKey
    mTime::Cdouble
    mValues::Ptr{Cuint}
    mWeights::Ptr{Cdouble}
    mNumValuesAndWeights::Cuint
end

struct aiMeshMorphAnim
    mName::aiString
    mNumKeys::Cuint
    mKeys::Ptr{aiMeshMorphKey}
end

struct aiAnimation
    mName::aiString
    mDuration::Cdouble
    mTicksPerSecond::Cdouble
    mNumChannels::Cuint
    mChannels::Ptr{Ptr{aiNodeAnim}}
    mNumMeshChannels::Cuint
    mMeshChannels::Ptr{Ptr{aiMeshAnim}}
    mNumMorphMeshChannels::Cuint
    mMorphMeshChannels::Ptr{Ptr{aiMeshMorphAnim}}
end

struct aiTexel
    data::NTuple{4, UInt8}
end

function Base.getproperty(x::Ptr{aiTexel}, f::Symbol)
    f === :b && return Ptr{Cuchar}(x + 0)
    f === :g && return Ptr{Cuchar}(x + 1)
    f === :r && return Ptr{Cuchar}(x + 2)
    f === :a && return Ptr{Cuchar}(x + 3)
    return getfield(x, f)
end

function Base.getproperty(x::aiTexel, f::Symbol)
    r = Ref{aiTexel}(x)
    ptr = Base.unsafe_convert(Ptr{aiTexel}, r)
    fptr = getproperty(ptr, f)
    GC.@preserve r unsafe_load(fptr)
end

function Base.setproperty!(x::Ptr{aiTexel}, f::Symbol, v)
    unsafe_store!(getproperty(x, f), v)
end

function Base.propertynames(x::aiTexel, private::Bool = false)
    (:b, :g, :r, :a, if private
            fieldnames(typeof(x))
        else
            ()
        end...)
end

struct aiTexture
    mWidth::Cuint
    mHeight::Cuint
    achFormatHint::NTuple{9, Cchar}
    pcData::Ptr{aiTexel}
    mFilename::aiString
end

@cenum aiLightSourceType::UInt32 begin
    aiLightSource_UNDEFINED = 0
    aiLightSource_DIRECTIONAL = 1
    aiLightSource_POINT = 2
    aiLightSource_SPOT = 3
    aiLightSource_AMBIENT = 4
    aiLightSource_AREA = 5
    _aiLightSource_Force32Bit = 2147483647
end

struct aiLight
    mName::aiString
    mType::aiLightSourceType
    mPosition::aiVector3D
    mDirection::aiVector3D
    mUp::aiVector3D
    mAttenuationConstant::Cfloat
    mAttenuationLinear::Cfloat
    mAttenuationQuadratic::Cfloat
    mColorDiffuse::aiColor3D
    mColorSpecular::aiColor3D
    mColorAmbient::aiColor3D
    mAngleInnerCone::Cfloat
    mAngleOuterCone::Cfloat
    mSize::aiVector2D
end

struct aiCamera
    mName::aiString
    mPosition::aiVector3D
    mUp::aiVector3D
    mLookAt::aiVector3D
    mHorizontalFOV::Cfloat
    mClipPlaneNear::Cfloat
    mClipPlaneFar::Cfloat
    mAspect::Cfloat
    mOrthographicWidth::Cfloat
end

struct aiSkeletonBone
    mParent::Cint
    mArmature::Ptr{aiNode}
    mNode::Ptr{aiNode}
    mNumnWeights::Cuint
    mMeshId::Ptr{aiMesh}
    mWeights::Ptr{aiVertexWeight}
    mOffsetMatrix::aiMatrix4x4
    mLocalMatrix::aiMatrix4x4
end

struct aiSkeleton
    mName::aiString
    mNumBones::Cuint
    mBones::Ptr{Ptr{aiSkeletonBone}}
end

struct aiScene
    mFlags::Cuint
    mRootNode::Ptr{aiNode}
    mNumMeshes::Cuint
    mMeshes::Ptr{Ptr{aiMesh}}
    mNumMaterials::Cuint
    mMaterials::Ptr{Ptr{aiMaterial}}
    mNumAnimations::Cuint
    mAnimations::Ptr{Ptr{aiAnimation}}
    mNumTextures::Cuint
    mTextures::Ptr{Ptr{aiTexture}}
    mNumLights::Cuint
    mLights::Ptr{Ptr{aiLight}}
    mNumCameras::Cuint
    mCameras::Ptr{Ptr{aiCamera}}
    mMetaData::Ptr{aiMetadata}
    mName::aiString
    mNumSkeletons::Cuint
    mSkeletons::Ptr{Ptr{aiSkeleton}}
    mPrivate::Ptr{Cchar}
end

function aiImportFile(pFile, pFlags)
    ccall((:aiImportFile, libassimp), Ptr{aiScene}, (Ptr{Cchar}, Cuint), pFile, pFlags)
end

function aiImportFileEx(pFile, pFlags, pFS)
    ccall((:aiImportFileEx, libassimp), Ptr{aiScene}, (Ptr{Cchar}, Cuint, Ptr{aiFileIO}), pFile, pFlags, pFS)
end

function aiImportFileExWithProperties(pFile, pFlags, pFS, pProps)
    ccall((:aiImportFileExWithProperties, libassimp), Ptr{aiScene}, (Ptr{Cchar}, Cuint, Ptr{aiFileIO}, Ptr{aiPropertyStore}), pFile, pFlags, pFS, pProps)
end

function aiImportFileFromMemory(pBuffer, pLength, pFlags, pHint)
    ccall((:aiImportFileFromMemory, libassimp), Ptr{aiScene}, (Ptr{Cchar}, Cuint, Cuint, Ptr{Cchar}), pBuffer, pLength, pFlags, pHint)
end

function aiImportFileFromMemoryWithProperties(pBuffer, pLength, pFlags, pHint, pProps)
    ccall((:aiImportFileFromMemoryWithProperties, libassimp), Ptr{aiScene}, (Ptr{Cchar}, Cuint, Cuint, Ptr{Cchar}, Ptr{aiPropertyStore}), pBuffer, pLength, pFlags, pHint, pProps)
end

function aiApplyPostProcessing(pScene, pFlags)
    ccall((:aiApplyPostProcessing, libassimp), Ptr{aiScene}, (Ptr{aiScene}, Cuint), pScene, pFlags)
end

function aiGetPredefinedLogStream(pStreams, file)
    ccall((:aiGetPredefinedLogStream, libassimp), aiLogStream, (aiDefaultLogStream, Ptr{Cchar}), pStreams, file)
end

function aiAttachLogStream(stream)
    ccall((:aiAttachLogStream, libassimp), Cvoid, (Ptr{aiLogStream},), stream)
end

function aiEnableVerboseLogging(d)
    ccall((:aiEnableVerboseLogging, libassimp), Cvoid, (aiBool,), d)
end

function aiDetachLogStream(stream)
    ccall((:aiDetachLogStream, libassimp), aiReturn, (Ptr{aiLogStream},), stream)
end

function aiDetachAllLogStreams()
    ccall((:aiDetachAllLogStreams, libassimp), Cvoid, ())
end

function aiReleaseImport(pScene)
    ccall((:aiReleaseImport, libassimp), Cvoid, (Ptr{aiScene},), pScene)
end

function aiGetErrorString()
    ccall((:aiGetErrorString, libassimp), Ptr{Cchar}, ())
end

function aiIsExtensionSupported(szExtension)
    ccall((:aiIsExtensionSupported, libassimp), aiBool, (Ptr{Cchar},), szExtension)
end

function aiGetExtensionList(szOut)
    ccall((:aiGetExtensionList, libassimp), Cvoid, (Ptr{aiString},), szOut)
end

function aiGetMemoryRequirements(pIn, in)
    ccall((:aiGetMemoryRequirements, libassimp), Cvoid, (Ptr{aiScene}, Ptr{aiMemoryInfo}), pIn, in)
end

function aiCreatePropertyStore()
    ccall((:aiCreatePropertyStore, libassimp), Ptr{aiPropertyStore}, ())
end

function aiReleasePropertyStore(p)
    ccall((:aiReleasePropertyStore, libassimp), Cvoid, (Ptr{aiPropertyStore},), p)
end

function aiSetImportPropertyInteger(store, szName, value)
    ccall((:aiSetImportPropertyInteger, libassimp), Cvoid, (Ptr{aiPropertyStore}, Ptr{Cchar}, Cint), store, szName, value)
end

function aiSetImportPropertyFloat(store, szName, value)
    ccall((:aiSetImportPropertyFloat, libassimp), Cvoid, (Ptr{aiPropertyStore}, Ptr{Cchar}, ai_real), store, szName, value)
end

function aiSetImportPropertyString(store, szName, st)
    ccall((:aiSetImportPropertyString, libassimp), Cvoid, (Ptr{aiPropertyStore}, Ptr{Cchar}, Ptr{aiString}), store, szName, st)
end

function aiSetImportPropertyMatrix(store, szName, mat)
    ccall((:aiSetImportPropertyMatrix, libassimp), Cvoid, (Ptr{aiPropertyStore}, Ptr{Cchar}, Ptr{aiMatrix4x4}), store, szName, mat)
end

function aiCreateQuaternionFromMatrix(quat, mat)
    ccall((:aiCreateQuaternionFromMatrix, libassimp), Cvoid, (Ptr{aiQuaternion}, Ptr{aiMatrix3x3}), quat, mat)
end

function aiDecomposeMatrix(mat, scaling, rotation, position)
    ccall((:aiDecomposeMatrix, libassimp), Cvoid, (Ptr{aiMatrix4x4}, Ptr{aiVector3D}, Ptr{aiQuaternion}, Ptr{aiVector3D}), mat, scaling, rotation, position)
end

function aiTransposeMatrix4(mat)
    ccall((:aiTransposeMatrix4, libassimp), Cvoid, (Ptr{aiMatrix4x4},), mat)
end

function aiTransposeMatrix3(mat)
    ccall((:aiTransposeMatrix3, libassimp), Cvoid, (Ptr{aiMatrix3x3},), mat)
end

function aiTransformVecByMatrix3(vec, mat)
    ccall((:aiTransformVecByMatrix3, libassimp), Cvoid, (Ptr{aiVector3D}, Ptr{aiMatrix3x3}), vec, mat)
end

function aiTransformVecByMatrix4(vec, mat)
    ccall((:aiTransformVecByMatrix4, libassimp), Cvoid, (Ptr{aiVector3D}, Ptr{aiMatrix4x4}), vec, mat)
end

function aiMultiplyMatrix4(dst, src)
    ccall((:aiMultiplyMatrix4, libassimp), Cvoid, (Ptr{aiMatrix4x4}, Ptr{aiMatrix4x4}), dst, src)
end

function aiMultiplyMatrix3(dst, src)
    ccall((:aiMultiplyMatrix3, libassimp), Cvoid, (Ptr{aiMatrix3x3}, Ptr{aiMatrix3x3}), dst, src)
end

function aiIdentityMatrix3(mat)
    ccall((:aiIdentityMatrix3, libassimp), Cvoid, (Ptr{aiMatrix3x3},), mat)
end

function aiIdentityMatrix4(mat)
    ccall((:aiIdentityMatrix4, libassimp), Cvoid, (Ptr{aiMatrix4x4},), mat)
end

function aiGetImportFormatCount()
    ccall((:aiGetImportFormatCount, libassimp), Csize_t, ())
end

function aiGetImportFormatDescription(pIndex)
    ccall((:aiGetImportFormatDescription, libassimp), Ptr{aiImporterDesc}, (Csize_t,), pIndex)
end

function aiVector2AreEqual(a, b)
    ccall((:aiVector2AreEqual, libassimp), Cint, (Ptr{aiVector2D}, Ptr{aiVector2D}), a, b)
end

function aiVector2AreEqualEpsilon(a, b, epsilon)
    ccall((:aiVector2AreEqualEpsilon, libassimp), Cint, (Ptr{aiVector2D}, Ptr{aiVector2D}, Cfloat), a, b, epsilon)
end

function aiVector2Add(dst, src)
    ccall((:aiVector2Add, libassimp), Cvoid, (Ptr{aiVector2D}, Ptr{aiVector2D}), dst, src)
end

function aiVector2Subtract(dst, src)
    ccall((:aiVector2Subtract, libassimp), Cvoid, (Ptr{aiVector2D}, Ptr{aiVector2D}), dst, src)
end

function aiVector2Scale(dst, s)
    ccall((:aiVector2Scale, libassimp), Cvoid, (Ptr{aiVector2D}, Cfloat), dst, s)
end

function aiVector2SymMul(dst, other)
    ccall((:aiVector2SymMul, libassimp), Cvoid, (Ptr{aiVector2D}, Ptr{aiVector2D}), dst, other)
end

function aiVector2DivideByScalar(dst, s)
    ccall((:aiVector2DivideByScalar, libassimp), Cvoid, (Ptr{aiVector2D}, Cfloat), dst, s)
end

function aiVector2DivideByVector(dst, v)
    ccall((:aiVector2DivideByVector, libassimp), Cvoid, (Ptr{aiVector2D}, Ptr{aiVector2D}), dst, v)
end

function aiVector2Length(v)
    ccall((:aiVector2Length, libassimp), Cfloat, (Ptr{aiVector2D},), v)
end

function aiVector2SquareLength(v)
    ccall((:aiVector2SquareLength, libassimp), Cfloat, (Ptr{aiVector2D},), v)
end

function aiVector2Negate(dst)
    ccall((:aiVector2Negate, libassimp), Cvoid, (Ptr{aiVector2D},), dst)
end

function aiVector2DotProduct(a, b)
    ccall((:aiVector2DotProduct, libassimp), Cfloat, (Ptr{aiVector2D}, Ptr{aiVector2D}), a, b)
end

function aiVector2Normalize(v)
    ccall((:aiVector2Normalize, libassimp), Cvoid, (Ptr{aiVector2D},), v)
end

function aiVector3AreEqual(a, b)
    ccall((:aiVector3AreEqual, libassimp), Cint, (Ptr{aiVector3D}, Ptr{aiVector3D}), a, b)
end

function aiVector3AreEqualEpsilon(a, b, epsilon)
    ccall((:aiVector3AreEqualEpsilon, libassimp), Cint, (Ptr{aiVector3D}, Ptr{aiVector3D}, Cfloat), a, b, epsilon)
end

function aiVector3LessThan(a, b)
    ccall((:aiVector3LessThan, libassimp), Cint, (Ptr{aiVector3D}, Ptr{aiVector3D}), a, b)
end

function aiVector3Add(dst, src)
    ccall((:aiVector3Add, libassimp), Cvoid, (Ptr{aiVector3D}, Ptr{aiVector3D}), dst, src)
end

function aiVector3Subtract(dst, src)
    ccall((:aiVector3Subtract, libassimp), Cvoid, (Ptr{aiVector3D}, Ptr{aiVector3D}), dst, src)
end

function aiVector3Scale(dst, s)
    ccall((:aiVector3Scale, libassimp), Cvoid, (Ptr{aiVector3D}, Cfloat), dst, s)
end

function aiVector3SymMul(dst, other)
    ccall((:aiVector3SymMul, libassimp), Cvoid, (Ptr{aiVector3D}, Ptr{aiVector3D}), dst, other)
end

function aiVector3DivideByScalar(dst, s)
    ccall((:aiVector3DivideByScalar, libassimp), Cvoid, (Ptr{aiVector3D}, Cfloat), dst, s)
end

function aiVector3DivideByVector(dst, v)
    ccall((:aiVector3DivideByVector, libassimp), Cvoid, (Ptr{aiVector3D}, Ptr{aiVector3D}), dst, v)
end

function aiVector3Length(v)
    ccall((:aiVector3Length, libassimp), Cfloat, (Ptr{aiVector3D},), v)
end

function aiVector3SquareLength(v)
    ccall((:aiVector3SquareLength, libassimp), Cfloat, (Ptr{aiVector3D},), v)
end

function aiVector3Negate(dst)
    ccall((:aiVector3Negate, libassimp), Cvoid, (Ptr{aiVector3D},), dst)
end

function aiVector3DotProduct(a, b)
    ccall((:aiVector3DotProduct, libassimp), Cfloat, (Ptr{aiVector3D}, Ptr{aiVector3D}), a, b)
end

function aiVector3CrossProduct(dst, a, b)
    ccall((:aiVector3CrossProduct, libassimp), Cvoid, (Ptr{aiVector3D}, Ptr{aiVector3D}, Ptr{aiVector3D}), dst, a, b)
end

function aiVector3Normalize(v)
    ccall((:aiVector3Normalize, libassimp), Cvoid, (Ptr{aiVector3D},), v)
end

function aiVector3NormalizeSafe(v)
    ccall((:aiVector3NormalizeSafe, libassimp), Cvoid, (Ptr{aiVector3D},), v)
end

function aiVector3RotateByQuaternion(v, q)
    ccall((:aiVector3RotateByQuaternion, libassimp), Cvoid, (Ptr{aiVector3D}, Ptr{aiQuaternion}), v, q)
end

function aiMatrix3FromMatrix4(dst, mat)
    ccall((:aiMatrix3FromMatrix4, libassimp), Cvoid, (Ptr{aiMatrix3x3}, Ptr{aiMatrix4x4}), dst, mat)
end

function aiMatrix3FromQuaternion(mat, q)
    ccall((:aiMatrix3FromQuaternion, libassimp), Cvoid, (Ptr{aiMatrix3x3}, Ptr{aiQuaternion}), mat, q)
end

function aiMatrix3AreEqual(a, b)
    ccall((:aiMatrix3AreEqual, libassimp), Cint, (Ptr{aiMatrix3x3}, Ptr{aiMatrix3x3}), a, b)
end

function aiMatrix3AreEqualEpsilon(a, b, epsilon)
    ccall((:aiMatrix3AreEqualEpsilon, libassimp), Cint, (Ptr{aiMatrix3x3}, Ptr{aiMatrix3x3}, Cfloat), a, b, epsilon)
end

function aiMatrix3Inverse(mat)
    ccall((:aiMatrix3Inverse, libassimp), Cvoid, (Ptr{aiMatrix3x3},), mat)
end

function aiMatrix3Determinant(mat)
    ccall((:aiMatrix3Determinant, libassimp), Cfloat, (Ptr{aiMatrix3x3},), mat)
end

function aiMatrix3RotationZ(mat, angle)
    ccall((:aiMatrix3RotationZ, libassimp), Cvoid, (Ptr{aiMatrix3x3}, Cfloat), mat, angle)
end

function aiMatrix3FromRotationAroundAxis(mat, axis, angle)
    ccall((:aiMatrix3FromRotationAroundAxis, libassimp), Cvoid, (Ptr{aiMatrix3x3}, Ptr{aiVector3D}, Cfloat), mat, axis, angle)
end

function aiMatrix3Translation(mat, translation)
    ccall((:aiMatrix3Translation, libassimp), Cvoid, (Ptr{aiMatrix3x3}, Ptr{aiVector2D}), mat, translation)
end

function aiMatrix3FromTo(mat, from, to)
    ccall((:aiMatrix3FromTo, libassimp), Cvoid, (Ptr{aiMatrix3x3}, Ptr{aiVector3D}, Ptr{aiVector3D}), mat, from, to)
end

function aiMatrix4FromMatrix3(dst, mat)
    ccall((:aiMatrix4FromMatrix3, libassimp), Cvoid, (Ptr{aiMatrix4x4}, Ptr{aiMatrix3x3}), dst, mat)
end

function aiMatrix4FromScalingQuaternionPosition(mat, scaling, rotation, position)
    ccall((:aiMatrix4FromScalingQuaternionPosition, libassimp), Cvoid, (Ptr{aiMatrix4x4}, Ptr{aiVector3D}, Ptr{aiQuaternion}, Ptr{aiVector3D}), mat, scaling, rotation, position)
end

function aiMatrix4Add(dst, src)
    ccall((:aiMatrix4Add, libassimp), Cvoid, (Ptr{aiMatrix4x4}, Ptr{aiMatrix4x4}), dst, src)
end

function aiMatrix4AreEqual(a, b)
    ccall((:aiMatrix4AreEqual, libassimp), Cint, (Ptr{aiMatrix4x4}, Ptr{aiMatrix4x4}), a, b)
end

function aiMatrix4AreEqualEpsilon(a, b, epsilon)
    ccall((:aiMatrix4AreEqualEpsilon, libassimp), Cint, (Ptr{aiMatrix4x4}, Ptr{aiMatrix4x4}, Cfloat), a, b, epsilon)
end

function aiMatrix4Inverse(mat)
    ccall((:aiMatrix4Inverse, libassimp), Cvoid, (Ptr{aiMatrix4x4},), mat)
end

function aiMatrix4Determinant(mat)
    ccall((:aiMatrix4Determinant, libassimp), Cfloat, (Ptr{aiMatrix4x4},), mat)
end

function aiMatrix4IsIdentity(mat)
    ccall((:aiMatrix4IsIdentity, libassimp), Cint, (Ptr{aiMatrix4x4},), mat)
end

function aiMatrix4DecomposeIntoScalingEulerAnglesPosition(mat, scaling, rotation, position)
    ccall((:aiMatrix4DecomposeIntoScalingEulerAnglesPosition, libassimp), Cvoid, (Ptr{aiMatrix4x4}, Ptr{aiVector3D}, Ptr{aiVector3D}, Ptr{aiVector3D}), mat, scaling, rotation, position)
end

function aiMatrix4DecomposeIntoScalingAxisAnglePosition(mat, scaling, axis, angle, position)
    ccall((:aiMatrix4DecomposeIntoScalingAxisAnglePosition, libassimp), Cvoid, (Ptr{aiMatrix4x4}, Ptr{aiVector3D}, Ptr{aiVector3D}, Ptr{ai_real}, Ptr{aiVector3D}), mat, scaling, axis, angle, position)
end

function aiMatrix4DecomposeNoScaling(mat, rotation, position)
    ccall((:aiMatrix4DecomposeNoScaling, libassimp), Cvoid, (Ptr{aiMatrix4x4}, Ptr{aiQuaternion}, Ptr{aiVector3D}), mat, rotation, position)
end

function aiMatrix4FromEulerAngles(mat, x, y, z)
    ccall((:aiMatrix4FromEulerAngles, libassimp), Cvoid, (Ptr{aiMatrix4x4}, Cfloat, Cfloat, Cfloat), mat, x, y, z)
end

function aiMatrix4RotationX(mat, angle)
    ccall((:aiMatrix4RotationX, libassimp), Cvoid, (Ptr{aiMatrix4x4}, Cfloat), mat, angle)
end

function aiMatrix4RotationY(mat, angle)
    ccall((:aiMatrix4RotationY, libassimp), Cvoid, (Ptr{aiMatrix4x4}, Cfloat), mat, angle)
end

function aiMatrix4RotationZ(mat, angle)
    ccall((:aiMatrix4RotationZ, libassimp), Cvoid, (Ptr{aiMatrix4x4}, Cfloat), mat, angle)
end

function aiMatrix4FromRotationAroundAxis(mat, axis, angle)
    ccall((:aiMatrix4FromRotationAroundAxis, libassimp), Cvoid, (Ptr{aiMatrix4x4}, Ptr{aiVector3D}, Cfloat), mat, axis, angle)
end

function aiMatrix4Translation(mat, translation)
    ccall((:aiMatrix4Translation, libassimp), Cvoid, (Ptr{aiMatrix4x4}, Ptr{aiVector3D}), mat, translation)
end

function aiMatrix4Scaling(mat, scaling)
    ccall((:aiMatrix4Scaling, libassimp), Cvoid, (Ptr{aiMatrix4x4}, Ptr{aiVector3D}), mat, scaling)
end

function aiMatrix4FromTo(mat, from, to)
    ccall((:aiMatrix4FromTo, libassimp), Cvoid, (Ptr{aiMatrix4x4}, Ptr{aiVector3D}, Ptr{aiVector3D}), mat, from, to)
end

function aiQuaternionFromEulerAngles(q, x, y, z)
    ccall((:aiQuaternionFromEulerAngles, libassimp), Cvoid, (Ptr{aiQuaternion}, Cfloat, Cfloat, Cfloat), q, x, y, z)
end

function aiQuaternionFromAxisAngle(q, axis, angle)
    ccall((:aiQuaternionFromAxisAngle, libassimp), Cvoid, (Ptr{aiQuaternion}, Ptr{aiVector3D}, Cfloat), q, axis, angle)
end

function aiQuaternionFromNormalizedQuaternion(q, normalized)
    ccall((:aiQuaternionFromNormalizedQuaternion, libassimp), Cvoid, (Ptr{aiQuaternion}, Ptr{aiVector3D}), q, normalized)
end

function aiQuaternionAreEqual(a, b)
    ccall((:aiQuaternionAreEqual, libassimp), Cint, (Ptr{aiQuaternion}, Ptr{aiQuaternion}), a, b)
end

function aiQuaternionAreEqualEpsilon(a, b, epsilon)
    ccall((:aiQuaternionAreEqualEpsilon, libassimp), Cint, (Ptr{aiQuaternion}, Ptr{aiQuaternion}, Cfloat), a, b, epsilon)
end

function aiQuaternionNormalize(q)
    ccall((:aiQuaternionNormalize, libassimp), Cvoid, (Ptr{aiQuaternion},), q)
end

function aiQuaternionConjugate(q)
    ccall((:aiQuaternionConjugate, libassimp), Cvoid, (Ptr{aiQuaternion},), q)
end

function aiQuaternionMultiply(dst, q)
    ccall((:aiQuaternionMultiply, libassimp), Cvoid, (Ptr{aiQuaternion}, Ptr{aiQuaternion}), dst, q)
end

function aiQuaternionInterpolate(dst, start, _end, factor)
    ccall((:aiQuaternionInterpolate, libassimp), Cvoid, (Ptr{aiQuaternion}, Ptr{aiQuaternion}, Ptr{aiQuaternion}, Cfloat), dst, start, _end, factor)
end

@cenum aiPrimitiveType::UInt32 begin
    aiPrimitiveType_POINT = 1
    aiPrimitiveType_LINE = 2
    aiPrimitiveType_TRIANGLE = 4
    aiPrimitiveType_POLYGON = 8
    aiPrimitiveType_NGONEncodingFlag = 16
    _aiPrimitiveType_Force32Bit = 2147483647
end

@cenum aiMorphingMethod::UInt32 begin
    aiMorphingMethod_VERTEX_BLEND = 1
    aiMorphingMethod_MORPH_NORMALIZED = 2
    aiMorphingMethod_MORPH_RELATIVE = 3
    _aiMorphingMethod_Force32Bit = 2147483647
end

@cenum aiTextureOp::UInt32 begin
    aiTextureOp_Multiply = 0
    aiTextureOp_Add = 1
    aiTextureOp_Subtract = 2
    aiTextureOp_Divide = 3
    aiTextureOp_SmoothAdd = 4
    aiTextureOp_SignedAdd = 5
    _aiTextureOp_Force32Bit = 2147483647
end

@cenum aiTextureMapMode::UInt32 begin
    aiTextureMapMode_Wrap = 0
    aiTextureMapMode_Clamp = 1
    aiTextureMapMode_Decal = 3
    aiTextureMapMode_Mirror = 2
    _aiTextureMapMode_Force32Bit = 2147483647
end

@cenum aiTextureMapping::UInt32 begin
    aiTextureMapping_UV = 0
    aiTextureMapping_SPHERE = 1
    aiTextureMapping_CYLINDER = 2
    aiTextureMapping_BOX = 3
    aiTextureMapping_PLANE = 4
    aiTextureMapping_OTHER = 5
    _aiTextureMapping_Force32Bit = 2147483647
end

@cenum aiTextureType::UInt32 begin
    aiTextureType_NONE = 0
    aiTextureType_DIFFUSE = 1
    aiTextureType_SPECULAR = 2
    aiTextureType_AMBIENT = 3
    aiTextureType_EMISSIVE = 4
    aiTextureType_HEIGHT = 5
    aiTextureType_NORMALS = 6
    aiTextureType_SHININESS = 7
    aiTextureType_OPACITY = 8
    aiTextureType_DISPLACEMENT = 9
    aiTextureType_LIGHTMAP = 10
    aiTextureType_REFLECTION = 11
    aiTextureType_BASE_COLOR = 12
    aiTextureType_NORMAL_CAMERA = 13
    aiTextureType_EMISSION_COLOR = 14
    aiTextureType_METALNESS = 15
    aiTextureType_DIFFUSE_ROUGHNESS = 16
    aiTextureType_AMBIENT_OCCLUSION = 17
    aiTextureType_SHEEN = 19
    aiTextureType_CLEARCOAT = 20
    aiTextureType_TRANSMISSION = 21
    aiTextureType_UNKNOWN = 18
    _aiTextureType_Force32Bit = 2147483647
end

function aiTextureTypeToString(in)
    ccall((:aiTextureTypeToString, libassimp), Ptr{Cchar}, (aiTextureType,), in)
end

@cenum aiShadingMode::UInt32 begin
    aiShadingMode_Flat = 1
    aiShadingMode_Gouraud = 2
    aiShadingMode_Phong = 3
    aiShadingMode_Blinn = 4
    aiShadingMode_Toon = 5
    aiShadingMode_OrenNayar = 6
    aiShadingMode_Minnaert = 7
    aiShadingMode_CookTorrance = 8
    aiShadingMode_NoShading = 9
    aiShadingMode_Unlit = 9
    aiShadingMode_Fresnel = 10
    aiShadingMode_PBR_BRDF = 11
    _aiShadingMode_Force32Bit = 2147483647
end

@cenum aiTextureFlags::UInt32 begin
    aiTextureFlags_Invert = 1
    aiTextureFlags_UseAlpha = 2
    aiTextureFlags_IgnoreAlpha = 4
    _aiTextureFlags_Force32Bit = 2147483647
end

@cenum aiBlendMode::UInt32 begin
    aiBlendMode_Default = 0
    aiBlendMode_Additive = 1
    _aiBlendMode_Force32Bit = 2147483647
end

struct aiUVTransform
    mTranslation::aiVector2D
    mScaling::aiVector2D
    mRotation::ai_real
end

function aiGetMaterialProperty(pMat, pKey, type, index, pPropOut)
    ccall((:aiGetMaterialProperty, libassimp), aiReturn, (Ptr{aiMaterial}, Ptr{Cchar}, Cuint, Cuint, Ptr{Ptr{aiMaterialProperty}}), pMat, pKey, type, index, pPropOut)
end

function aiGetMaterialFloatArray(pMat, pKey, type, index, pOut, pMax)
    ccall((:aiGetMaterialFloatArray, libassimp), aiReturn, (Ptr{aiMaterial}, Ptr{Cchar}, Cuint, Cuint, Ptr{ai_real}, Ptr{Cuint}), pMat, pKey, type, index, pOut, pMax)
end

function aiGetMaterialFloat(pMat, pKey, type, index, pOut)
    ccall((:aiGetMaterialFloat, libassimp), aiReturn, (Ptr{aiMaterial}, Ptr{Cchar}, Cuint, Cuint, Ptr{ai_real}), pMat, pKey, type, index, pOut)
end

function aiGetMaterialIntegerArray(pMat, pKey, type, index, pOut, pMax)
    ccall((:aiGetMaterialIntegerArray, libassimp), aiReturn, (Ptr{aiMaterial}, Ptr{Cchar}, Cuint, Cuint, Ptr{Cint}, Ptr{Cuint}), pMat, pKey, type, index, pOut, pMax)
end

function aiGetMaterialInteger(pMat, pKey, type, index, pOut)
    ccall((:aiGetMaterialInteger, libassimp), aiReturn, (Ptr{aiMaterial}, Ptr{Cchar}, Cuint, Cuint, Ptr{Cint}), pMat, pKey, type, index, pOut)
end

function aiGetMaterialColor(pMat, pKey, type, index, pOut)
    ccall((:aiGetMaterialColor, libassimp), aiReturn, (Ptr{aiMaterial}, Ptr{Cchar}, Cuint, Cuint, Ptr{aiColor4D}), pMat, pKey, type, index, pOut)
end

function aiGetMaterialUVTransform(pMat, pKey, type, index, pOut)
    ccall((:aiGetMaterialUVTransform, libassimp), aiReturn, (Ptr{aiMaterial}, Ptr{Cchar}, Cuint, Cuint, Ptr{aiUVTransform}), pMat, pKey, type, index, pOut)
end

function aiGetMaterialString(pMat, pKey, type, index, pOut)
    ccall((:aiGetMaterialString, libassimp), aiReturn, (Ptr{aiMaterial}, Ptr{Cchar}, Cuint, Cuint, Ptr{aiString}), pMat, pKey, type, index, pOut)
end

function aiGetMaterialTextureCount(pMat, type)
    ccall((:aiGetMaterialTextureCount, libassimp), Cuint, (Ptr{aiMaterial}, aiTextureType), pMat, type)
end

function aiGetMaterialTexture(mat, type, index, path, mapping, uvindex, blend, op, mapmode, flags)
    ccall((:aiGetMaterialTexture, libassimp), aiReturn, (Ptr{aiMaterial}, aiTextureType, Cuint, Ptr{aiString}, Ptr{aiTextureMapping}, Ptr{Cuint}, Ptr{ai_real}, Ptr{aiTextureOp}, Ptr{aiTextureMapMode}, Ptr{Cuint}), mat, type, index, path, mapping, uvindex, blend, op, mapmode, flags)
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

# Skipping MacroDefinition: AI_FORCE_INLINE inline

# Skipping MacroDefinition: AI_WONT_RETURN_SUFFIX __attribute__ ( ( noreturn ) )

# Skipping MacroDefinition: C_STRUCT struct

# Skipping MacroDefinition: C_ENUM enum

const ASSIMP_AI_REAL_TEXT_PRECISION = 9

const AI_MATH_PI = 3.141592653589793

const AI_MATH_TWO_PI = AI_MATH_PI * 2.0

const AI_MATH_HALF_PI = AI_MATH_PI * 0.5

const AI_MATH_PI_F = Float32(3.1415926538)

const AI_MATH_TWO_PI_F = AI_MATH_PI_F * Float32(2.0)

const AI_MATH_HALF_PI_F = AI_MATH_PI_F * Float32(0.5)

const MAXLEN = 1024

const AI_SUCCESS = aiReturn_SUCCESS

const AI_FAILURE = aiReturn_FAILURE

const AI_OUTOFMEMORY = aiReturn_OUTOFMEMORY

const DLS_FILE = aiDefaultLogStream_FILE

const DLS_STDOUT = aiDefaultLogStream_STDOUT

const DLS_STDERR = aiDefaultLogStream_STDERR

const DLS_DEBUGGER = aiDefaultLogStream_DEBUGGER

const AI_FALSE = 0

const AI_TRUE = 1

const AI_EMBEDDED_TEXNAME_PREFIX = "*"

# Skipping MacroDefinition: PACK_STRUCT __attribute__ ( ( __packed__ ) )

const HINTMAXTEXTURELEN = 9

const AI_MAX_FACE_INDICES = 0x7fff

const AI_MAX_BONE_WEIGHTS = 0x7fffffff

const AI_MAX_VERTICES = 0x7fffffff

const AI_MAX_FACES = 0x7fffffff

const AI_MAX_NUMBER_OF_COLOR_SETS = 0x08

const AI_MAX_NUMBER_OF_TEXTURECOORDS = 0x08

const AI_DEFAULT_MATERIAL_NAME = "DefaultMaterial"

const AI_TEXTURE_TYPE_MAX = aiTextureType_TRANSMISSION

const AI_MATKEY_NAME = ("?mat.name", 0, 0)

const AI_MATKEY_TWOSIDED = ("\$mat.twosided", 0, 0)

const AI_MATKEY_SHADING_MODEL = ("\$mat.shadingm", 0, 0)

const AI_MATKEY_ENABLE_WIREFRAME = ("\$mat.wireframe", 0, 0)

const AI_MATKEY_BLEND_FUNC = ("\$mat.blend", 0, 0)

const AI_MATKEY_OPACITY = ("\$mat.opacity", 0, 0)

const AI_MATKEY_TRANSPARENCYFACTOR = ("\$mat.transparencyfactor", 0, 0)

const AI_MATKEY_BUMPSCALING = ("\$mat.bumpscaling", 0, 0)

const AI_MATKEY_SHININESS = ("\$mat.shininess", 0, 0)

const AI_MATKEY_REFLECTIVITY = ("\$mat.reflectivity", 0, 0)

const AI_MATKEY_SHININESS_STRENGTH = ("\$mat.shinpercent", 0, 0)

const AI_MATKEY_REFRACTI = ("\$mat.refracti", 0, 0)

const AI_MATKEY_COLOR_DIFFUSE = ("\$clr.diffuse", 0, 0)

const AI_MATKEY_COLOR_AMBIENT = ("\$clr.ambient", 0, 0)

const AI_MATKEY_COLOR_SPECULAR = ("\$clr.specular", 0, 0)

const AI_MATKEY_COLOR_EMISSIVE = ("\$clr.emissive", 0, 0)

const AI_MATKEY_COLOR_TRANSPARENT = ("\$clr.transparent", 0, 0)

const AI_MATKEY_COLOR_REFLECTIVE = ("\$clr.reflective", 0, 0)

const AI_MATKEY_GLOBAL_BACKGROUND_IMAGE = ("?bg.global", 0, 0)

const AI_MATKEY_GLOBAL_SHADERLANG = ("?sh.lang", 0, 0)

const AI_MATKEY_SHADER_VERTEX = ("?sh.vs", 0, 0)

const AI_MATKEY_SHADER_FRAGMENT = ("?sh.fs", 0, 0)

const AI_MATKEY_SHADER_GEO = ("?sh.gs", 0, 0)

const AI_MATKEY_SHADER_TESSELATION = ("?sh.ts", 0, 0)

const AI_MATKEY_SHADER_PRIMITIVE = ("?sh.ps", 0, 0)

const AI_MATKEY_SHADER_COMPUTE = ("?sh.cs", 0, 0)

const AI_MATKEY_USE_COLOR_MAP = ("\$mat.useColorMap", 0, 0)

const AI_MATKEY_BASE_COLOR = ("\$clr.base", 0, 0)

const AI_MATKEY_BASE_COLOR_TEXTURE = (aiTextureType_BASE_COLOR, 0)

const AI_MATKEY_USE_METALLIC_MAP = ("\$mat.useMetallicMap", 0, 0)

const AI_MATKEY_METALLIC_FACTOR = ("\$mat.metallicFactor", 0, 0)

const AI_MATKEY_METALLIC_TEXTURE = (aiTextureType_METALNESS, 0)

const AI_MATKEY_USE_ROUGHNESS_MAP = ("\$mat.useRoughnessMap", 0, 0)

const AI_MATKEY_ROUGHNESS_FACTOR = ("\$mat.roughnessFactor", 0, 0)

const AI_MATKEY_ROUGHNESS_TEXTURE = (aiTextureType_DIFFUSE_ROUGHNESS, 0)

const AI_MATKEY_ANISOTROPY_FACTOR = ("\$mat.anisotropyFactor", 0, 0)

const AI_MATKEY_SPECULAR_FACTOR = ("\$mat.specularFactor", 0, 0)

const AI_MATKEY_GLOSSINESS_FACTOR = ("\$mat.glossinessFactor", 0, 0)

const AI_MATKEY_SHEEN_COLOR_FACTOR = ("\$clr.sheen.factor", 0, 0)

const AI_MATKEY_SHEEN_ROUGHNESS_FACTOR = ("\$mat.sheen.roughnessFactor", 0, 0)

const AI_MATKEY_SHEEN_COLOR_TEXTURE = (aiTextureType_SHEEN, 0)

const AI_MATKEY_SHEEN_ROUGHNESS_TEXTURE = (aiTextureType_SHEEN, 1)

const AI_MATKEY_CLEARCOAT_FACTOR = ("\$mat.clearcoat.factor", 0, 0)

const AI_MATKEY_CLEARCOAT_ROUGHNESS_FACTOR = ("\$mat.clearcoat.roughnessFactor", 0, 0)

const AI_MATKEY_CLEARCOAT_TEXTURE = (aiTextureType_CLEARCOAT, 0)

const AI_MATKEY_CLEARCOAT_ROUGHNESS_TEXTURE = (aiTextureType_CLEARCOAT, 1)

const AI_MATKEY_CLEARCOAT_NORMAL_TEXTURE = (aiTextureType_CLEARCOAT, 2)

const AI_MATKEY_TRANSMISSION_FACTOR = ("\$mat.transmission.factor", 0, 0)

const AI_MATKEY_TRANSMISSION_TEXTURE = (aiTextureType_TRANSMISSION, 0)

const AI_MATKEY_VOLUME_THICKNESS_FACTOR = ("\$mat.volume.thicknessFactor", 0, 0)

const AI_MATKEY_VOLUME_THICKNESS_TEXTURE = (aiTextureType_TRANSMISSION, 1)

const AI_MATKEY_VOLUME_ATTENUATION_DISTANCE = ("\$mat.volume.attenuationDistance", 0, 0)

const AI_MATKEY_VOLUME_ATTENUATION_COLOR = ("\$mat.volume.attenuationColor", 0, 0)

const AI_MATKEY_USE_EMISSIVE_MAP = ("\$mat.useEmissiveMap", 0, 0)

const AI_MATKEY_EMISSIVE_INTENSITY = ("\$mat.emissiveIntensity", 0, 0)

const AI_MATKEY_USE_AO_MAP = ("\$mat.useAOMap", 0, 0)

const _AI_MATKEY_TEXTURE_BASE = "\$tex.file"

const _AI_MATKEY_UVWSRC_BASE = "\$tex.uvwsrc"

const _AI_MATKEY_TEXOP_BASE = "\$tex.op"

const _AI_MATKEY_MAPPING_BASE = "\$tex.mapping"

const _AI_MATKEY_TEXBLEND_BASE = "\$tex.blend"

const _AI_MATKEY_MAPPINGMODE_U_BASE = "\$tex.mapmodeu"

const _AI_MATKEY_MAPPINGMODE_V_BASE = "\$tex.mapmodev"

const _AI_MATKEY_TEXMAP_AXIS_BASE = "\$tex.mapaxis"

const _AI_MATKEY_UVTRANSFORM_BASE = "\$tex.uvtrafo"

const _AI_MATKEY_TEXFLAGS_BASE = "\$tex.flags"

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