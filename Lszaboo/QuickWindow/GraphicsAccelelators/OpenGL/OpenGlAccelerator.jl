using ModernGL

struct OpenGLAccelerator <: AGraphicsAccelerator
    
    _data📚::WindowData
    
    function OpenGLAccelerator(data📚::WindowData)
        new(data📚)
    end
end

function init!(accelerator::OpenGLAccelerator)
    glClearColor(accelerator._data📚.clearColor[1],
                accelerator._data📚.clearColor[2],
                accelerator._data📚.clearColor[3],
                accelerator._data📚.clearColor[4])
end

function update!(accelerator::OpenGLAccelerator)
    glClear(GL_COLOR_BUFFER_BIT)
end
