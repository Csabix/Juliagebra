#version 330 core

layout(location = 0) out vec4 out_color;
layout(location = 1) out uint out_id;

void main(){
    if(gl_FrontFacing){
        out_color = vec4(0.0,1.0,0.0,1.0);
    }else{
        out_color = vec4(1.0,0.0,0.0,1.0);
    }

    out_id = uint(0);
}