mutable struct Texture2D <: OpenGLWrapper
    _id::GLuint
    #_unit::GLuint #Like GL_TEXTURE0 wich is first input texture
    _width::Int
    _height::Int
    _internalFormat::GLuint
    _uploadFormat::GLuint
    _eachDataType::GLuint

    function Texture2D(width::Int,height::Int,internalFormat::GLuint,uploadFormat::GLuint,eachDataType::GLuint)
        glPixelStorei(GL_UNPACK_ALIGNMENT, 1)
        
        id = Ref{GLuint}(0)
        glGenTextures(1,id)
        id = id[]
        
        self = new(id,width,height,internalFormat,uploadFormat,eachDataType)
        update!(self)
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE)
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE)
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST)
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST)

        return self
    end
end

function _updateSomeTexture!(id::GLuint,width::Int,height::Int,internalFormat::GLuint,uploadFormat::GLuint,eachDataType::GLuint,data=C_NULL)
    glBindTexture(GL_TEXTURE_2D, id)
    glTexImage2D(GL_TEXTURE_2D,0,internalFormat,width,height,0,uploadFormat,eachDataType,data)
end

activate(self::Texture2D,unit::GLuint) = (glActiveTexture(unit); glBindTexture(GL_TEXTURE_2D, self._id))
update!(self::Texture2D,data) = _updateSomeTexture!(self._id,self._width,self._height,self._internalFormat,self._uploadFormat,self._eachDataType,data)
update!(self::Texture2D) = update!(self,C_NULL)
destroy!(self::Texture2D) = glDeleteTextures(1,[self._id])

export Texture2D, activate, update!, destroy!

createRGBATexture2D(width::Int,height::Int)::Texture2D = Texture2D(width,height,GL_RGBA,GL_RGBA,GL_UNSIGNED_BYTE)
createIDTexture2D(width::Int,height::Int)::Texture2D = Texture2D(width,height,GL_R32I,GL_RED_INTEGER,GL_UNSIGNED_INT)
createDepthTexture2D(width::Int,height::Int)::Texture2D = Texture2D(width,height,GL_DEPTH_COMPONENT,GL_DEPTH_COMPONENT,GL_FLOAT)

export createRGBATexture2D, createIDTexture2D, createDepthTexture2D