#version 450
out vec4 fs_out_col;

uniform sampler2D frame;
uniform isampler2D idTex;

uniform int index = 0;
uniform float time = 0;

void main()
{
    fs_out_col = texelFetch(frame,ivec2(gl_FragCoord.xy),0);
    if (index !=0)
    {
        int id = texelFetch(idTex,ivec2(gl_FragCoord.xy),0).r;
        if (id == index)
        {
            fs_out_col += 0.25 + 0.25*sin(6*time);
        }
    }
}