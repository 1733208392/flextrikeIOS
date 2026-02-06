shader_type canvas_item;

uniform sampler2D texture_albedo : source_color;

void fragment() {
    vec4 tex_color = texture(texture_albedo, UV);
    // Handle alpha blending properly
    if (tex_color.a < 0.1) {
        discard;
    }
    COLOR = tex_color;
}