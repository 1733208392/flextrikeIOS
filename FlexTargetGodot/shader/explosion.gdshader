shader_type canvas_item;

uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform vec2 texture_size = vec2(100.0, 100.0);
uniform float strength = 1.0;

// We use COLOR to pass the centroid of each chunk (in UV coordinates 0..1)
// R = center U
// G = center V
// B = random seed / rotation speed
// A = unused

void vertex() {
    // Calculate the center of the chunk in local pixel coordinates
    vec2 center_uv = COLOR.rg;
    vec2 center_pos = center_uv * texture_size;
    
    // Calculate offset of this vertex from the chunk center
    vec2 offset = VERTEX - center_pos;
    
    // Animation parameters
    float t = progress * 1.5; // Speed multiplier
    float rnd = COLOR.b; // Random value passed in blue channel
    
    // Gravity
    float gravity = 1500.0 * t * t;
    
    // Explosion direction (away from center of image)
    vec2 dir = center_uv - vec2(0.5);
    // Add some randomness to direction
    dir = normalize(dir + vec2(rnd - 0.5, rnd - 0.5) * 0.5);
    
    // Displacement
    vec2 displacement = dir * strength * t * 800.0; // Explode outward
    displacement.y += gravity; // Add gravity
    
    // Rotation
    float rot_speed = (rnd - 0.5) * 20.0; // Random rotation speed
    float rot = rot_speed * t;
    float c = cos(rot);
    float s = sin(rot);
    mat2 rot_mat = mat2(vec2(c, -s), vec2(s, c));
    
    // Apply rotation to the offset (rotate around chunk center)
    vec2 rotated_offset = rot_mat * offset;
    
    // Final position
    VERTEX = center_pos + rotated_offset + displacement;
}

void fragment() {
    vec4 tex = texture(TEXTURE, UV);
    // Fade out
    tex.a *= (1.0 - smoothstep(0.7, 1.0, progress));
    COLOR = tex;
}
