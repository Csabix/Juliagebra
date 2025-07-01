using Glm
using Test
using StaticArrays

@testset "Vec types        " begin
    @test VecTN{Float32,2} == VecNT{2,Float32}
    @test sizeof(Vec2T{Bool}) == sizeof(BVec2)
    @test sizeof(Vec3) == 3*sizeof(Float32) # 12
    @test sizeof(DVec2) == 2*sizeof(Float64)
    @test sizeof(Vec3) == sizeof(Vec3(1,2,3))
    @test Vec3 == typeof(vec3(1,2,3))
    @test Vec2(1,2) isa FieldVector
    @test Vec4T{Float32}(1,2,3,4) isa VecNT
end

@testset "Vec constructors " begin
    @test Vec2(1,2) == vec2(1,2)
    @test Vec3(-3,-3,-3) == Vec3(-3)
    @test zero(IVec4) == ivec4(0)
    @test dvec3(-1,0,1) == vec3(ivec2(-1,0),1)
    @test vec3(0,1,2) == vec3(0,vec2(1,2))
    @test vec4(vec3(1),0) == Vec4(1,vec3(1,1,0))
    @test vec4(vec2(3,-4),vec2(-4,-1)) == vec4(3,-vec2(4),-1)
    @test_throws DimensionMismatch dvec2(1,2,3)
    @test_throws DimensionMismatch uvec4(1,2,3)
    @test_throws DimensionMismatch vec4(vec3(),vec2())
end

@testset "Vec member access" begin
    a = rand(Vec3)
    @test a.x === a[1] && a.y === a[2] && a.z === a[3]
    @test a["y"] === a.y
    @test a[(3,)] === a.z
    @test a["yx"] == a[(2,1)]
    @test a["zx"].y == a.x
    @test a["zzzz"] == vec4(a.z)
    b = rand(IVec4)
    @test b["wzyx"]["wzyx"] == b
    @test_throws BoundsError a[4]
    @test_throws BoundsError b[(5,)]
    @test_throws BoundsError a["w"]
    @test_throws BoundsError a["u"]
    @test_throws BoundsError b["{"] # 'z'+1
    @test_throws BoundsError b["xyzwx"]
end

@testset "Mat type creation" begin
    @test MatTN{Float32,2} == MatNT{2,Float32}
    @test DMat3 == DMat3x3
    @test sizeof(IMat4) == 4*sizeof(IVec4) == 4*4*sizeof(Int32)
    @test sizeof(Mat2) == sizeof(Mat2(1,2,3,4))
    @test Mat2(1,2,3,4) isa SMatrix
    @test Mat2T{Int128}(1,2,3,4) isa Mat2T
    @test Mat3(0,0,0,0,0,0,0,0,0) == mat3(0) == zero(Mat3)
    @test Mat2(1,0,0,1) == mat2(1) == one(Mat2)
end

@testset "Others           " begin
    A = mat2(1,2,3,4)
    @test Glm.vec2(A[:,1]) == vec2(1,2)
    eye,at,up = rand(Vec3),rand(Vec3),rand(Vec3)
    @test lookat(eye,at,up)*vec4(eye,1) ≈ vec4(0,0,0,1)
    @test string(A) isa String
    @test string(eye) isa String
end