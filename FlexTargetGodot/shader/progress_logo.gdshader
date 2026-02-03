shader_type canvas_item;

uniform float progress : hint_range(0.0, 1.0) = 0.0;

void fragment() {
    if (UV.y > 1.0 - progress) {
        float t = (UV.y - (1.0 - progress)) / progress;
        vec3 fill_color = vec3(1.0, 0.5, 0.0); // Orange
        COLOR = vec4(fill_color, 0.7);
    } else {
        COLOR = vec4(0.0, 0.0, 0.0, 0.0);
    }
}