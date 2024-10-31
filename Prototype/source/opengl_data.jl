
# * iter on employees to check changes
# * iter on opengldata for rendering

mutable struct OpenGLData
    _shrd::SharedData

    # TODO: Change Dictionary to an array. This suggestion might be a microoptimization.
    _renderOffices::Dict{<:DataType,Vector{<:RenderEmployee}}
    _updateMeQueue::Queue{RenderEmployee}
    _combinerShader::ShaderProgram

    function OpenGLData(glfw::GLFWData,shrd::SharedData)
        # ! for OpenGLData to succesfully construct, a GLFWData is required, but not stored
        glClearColor(1.0,0.0,1.0,1.0)
        
        myPath = (@__FILE__)
        myPath = myPath[1:(length(myPath) - length("opengl_data.jl"))]
        #println(myPath)
        combinerShader = ShaderProgram(myPath * "shaders/dflt_combiner.vert", myPath * "shaders/dflt_combiner.frag")

        renderOffices = Dict{DataType,Vector{<:RenderEmployee}}()
        updateMeQueue = Queue{RenderEmployee}()
        new(shrd,renderOffices,updateMeQueue,combinerShader)
    end
end

function update!(self::OpenGLData)
    while !isempty(self._updateMeQueue)
        employee = dequeue!(self._updateMeQueue)
        sanitize!(employee)
    end
    # * All the buffers are up to date at this point.
    # TODO: Rendering logic comes here    

    glClear(GL_COLOR_BUFFER_BIT)
end

function print_render_offices(self::OpenGLData)
    printstyled("---------------\n";color=:white, bold=true)
    printstyled("Render Offices:\n";color=:yellow, bold=true)
    printstyled("---------------\n";color=:white, bold=true)

    for (key,office) in self._renderOffices
        printstyled("- ";color=:red,bold=true)
        printstyled("$key:\n";color=:green)
        for employee in office
            printstyled("\t- ";color=:red,bold=true)
            printstyled("$(string(employee)) - $(string(employee._asset))\n";color=:cyan)
        end
    end

end


function destroy!(self::OpenGLData)
    delete(self._combinerShader)
end