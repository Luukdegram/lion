#version 330 core
layout (location = 0) in vec3 pos;
layout (location = 1) in vec2 texCoords;

out vec2 TextureCoords;

void main() 
{
    // Flip our y-axis to match it with chip8 video output's y-axis
    gl_Position = vec4(pos.x, pos.y * -1, pos.z, 1.0);
    TextureCoords = texCoords;
}