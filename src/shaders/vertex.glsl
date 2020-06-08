#version 330 core
layout (location = 0) in vec3 pos;

out vec2 TextureCoords;

void main() 
{
    gl_Position = vec4(pos, 1.0);
    TextureCoords = vec2(pos.x, pos.y);
}