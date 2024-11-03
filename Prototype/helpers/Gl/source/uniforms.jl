const LocType = Union{GLint,Int};

# generate automatic glUniform functions
for (jltype,glsuffix) in (Float32=>"f", Float64=>"d", Int32=>"i", UInt32=>"ui")
    glfunc = Symbol("glUniform1"*glsuffix)
    # println(glfunc)
    @eval glUniform(loc::LocType, data::$jltype)::Nothing = $glfunc(loc, data)
    for veclen in 2:4
        gltype = StaticVector{veclen,jltype}
        glfunc = Symbol("glUniform"*string(veclen)*glsuffix)
        # println(glfunc)
        @eval glUniform(loc::LocType, data::$gltype)::Nothing = $glfunc(loc, data...)
        gvtype = Vector{gltype}
        glfunc = Symbol("glUniform"*string(veclen)*glsuffix*"v")
        # println(glfunc)
        @eval glUniform(loc::LocType, data::$gvtype)::Nothing = $glfunc(loc, length(data), data)
    end
    gltype = AbstractVector{jltype}
    @eval function glUniform(loc::LocType, data::$gltype)::Nothing
        N = length(data)
        if 2<=N<=4
            glUniform(loc,SVector{N,$jltype}(data...))
        else
            glfunc = Symbol("glUniform1"*glsuffix*"v")
            @eval glUniform(loc::LocType, data::$jltype)::Nothing = $glfunc(loc, length(data), data)
        end
    end
end
for (jltype,glsuffix) in (Float32=>"fv", Float64=>"dv") #no int support
    for N = 2:4, M = 2:4
        gltype = StaticMatrix{N,M,jltype}
        sizestr= N==M ? string(N) : string(N)*string(M)
        glfunc = Symbol("glUniformMatrix"*sizestr*glsuffix)
        # println(glfunc)
        @eval glUniform(loc::LocType, data::$gltype)::Nothing = $glfunc(loc, 1, GL_FALSE, data)  
        gvtype = Vector{gltype}
        @eval glUniform(loc::LocType, data::$gvtype)::Nothing = $glfunc(loc, length(data), data)
    end
    gltype = AbstractMatrix{jltype}
    @eval function glUniform(loc::LocType, data::$gltype)::Nothing
        (N,M) = size(data)
        if 2<=N<=4 && 2<=M<=4
            glUniform(loc,SMatrix{N,M,$jltype}(data...))
        elseif N==1
            glUniform(loc,SVector{M,$jltype}(data...))  
        elseif M==1
            glUniform(loc,SVector{N,$jltype}(data...))            
        else
            error("Invalid matrix size: $N x $M")
        end
    end
end