#version 330 core

in vec2 TextureCoords;
out vec4 FragColor;

uniform sampler2D tex;

void main() {
    //test color
    //FragColor = vec4(1.0, 0.5, 0.5, 1.0);
    FragColor = texture(tex, TextureCoords);
}