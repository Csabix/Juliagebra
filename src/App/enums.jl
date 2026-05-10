
#abstract type FrameState end
#struct BuildingState <: FrameState end
#struct ViewingState <: FrameState end

abstract type Command end
struct EmptySceneCommand <: Command end