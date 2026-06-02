shader_type canvas_item;

// texture_albedo kept as unused uniform to avoid shader parameter errors in existing code
uniform sampler2D texture_albedo : source_color;
uniform float hole_alpha = 0.6;

void fragment() {
    float dist = distance(UV, vec2(0.5, 0.5));
    if (dist > 0.5) {
        discard;
    }
    COLOR = vec4(0.06, 0.04, 0.04, hole_alpha);
}