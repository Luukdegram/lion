#version 330 core

in vec2 TextureCoords;
out vec4 FragColor;

uniform sampler2D tex;

void main() {
    //FragColor = vec4(1.0f, 0.5f, 0.2f, 1.0f);
    FragColor = texture(tex, TextureCoords);
}