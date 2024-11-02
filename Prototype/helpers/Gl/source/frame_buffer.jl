

mutable struct FrameBuffer
    _id::GLuint

    function FrameBuffer(attachements::Dict{GLuint,Texture2D})
        id = Ref{GLuint}(0)
        glGenFramebuffers(1,id)
        id = id[]

        self = new(id)
        activate(self)

        attachmentPoints = Vector{GLenum}(undef,0)

        for (attachementPoint,texture) in attachements
            #println("$(attachementPoint) - $(texture._id)")
            
            glFramebufferTexture(GL_FRAMEBUFFER, attachementPoint, texture._id, 0)
            if (attachementPoint != GL_DEPTH_ATTACHMENT) && (attachementPoint != GL_STENCIL_ATTACHMENT)
                push!(attachmentPoints,attachementPoint)
            end
        end

        glDrawBuffers(length(attachmentPoints), attachmentPoints)
        if(glCheckFramebufferStatus(GL_FRAMEBUFFER) != GL_FRAMEBUFFER_COMPLETE)
            error("FrameBuffer creation failed!")
        end
        
        disable(self)

        return self
    end
end

activate(self::FrameBuffer) = glBindFramebuffer(GL_FRAMEBUFFER, self._id)
disable(self::FrameBuffer) = glBindFramebuffer(GL_FRAMEBUFFER, 0)
destroy!(self::FrameBuffer) =  glDeleteRenderbuffers(1,[self._id])

export FrameBuffer, activate, disable, destroy!