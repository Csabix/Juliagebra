#version 330 core

layout (points) in;
in float radius[];

layout (triangle_strip, max_vertices = 3) out;

uniform mat4 VP;

void main(){
    vec4 center = gl_in[0].gl_Position;
    float r = radius[0];

    gl_Position = VP * (center + vec4(0.0,0.0,1.0,0.0));
    EmitVertex(); 
    
    gl_Position = VP * (center + vec4(0.0,0.0,0.0,0.0));
    EmitVertex(); 

    gl_Position = VP * (center + vec4(0.0,1.0,0.0,0.0));
    EmitVertex(); 

    EndPrimitive();

}