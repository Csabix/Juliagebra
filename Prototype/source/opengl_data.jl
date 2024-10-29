abstract type AlgebraObject end
abstract type RenderPlan end
abstract type RenderEmployee end

# * iter on employees to check changes
# * iter on opengldata for rendering

mutable struct OpenGLData
    _shrd::SharedData

    # TODO: Change Dictionary to an array. This suggestion might be a microoptimization.
    _renderOffices::Dict{<:DataType,Vector{<:RenderEmployee}}

    function OpenGLData(glfw::GLFWData,shrd::SharedData)
        # ! for OpenGLData to succesfully construct, a GLFWData is required, but not stored
        glClearColor(1.0,0.0,1.0,1.0)

        renderOffices = Dict{DataType,Vector{<:RenderEmployee}}()
        new(shrd,renderOffices)
    end
end

function update!(self::OpenGLData)
    for (_, office) in self._renderOffices
        for employee in office
            actualize!(employee)
        end
    end
    # * All the buffers are up to date at this point.
    # TODO: Rendering logic comes here    

    glClear(GL_COLOR_BUFFER_BIT)
end

function hire_for_plan!(self::OpenGLData,plan::T) where T<:RenderPlan
    recruit!(self,plan)
    print_render_offices(self)
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
            printstyled("$(string(employee)) - $(string(employee._assets))\n";color=:cyan)
        end
    end

end


function destroy!(self::OpenGLData)

end