#version 330 core
layout (location = 0) in vec3 pos;

out vec2 TextureCoords;

void main() 
{
    gl_Position = vec4(pos, 1.0);
    // Flip our texture to match it with chip8 video output's y axis
    TextureCoords = vec2(pos.x, pos.y * -1);
}