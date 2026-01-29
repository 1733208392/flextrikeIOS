shader_type canvas_item;

uniform sampler2D noise_tex : hint_default_white;
uniform vec4 splat_color = vec4(1.0,0.2,0.2,1.0);
uniform float seed = 0.0;
uniform float edge_rough = 1.0; // strength of jaggedness
uniform float noise_scale = 6.0;
uniform int droplets = 5;

// cheap 1D hash
float hash(float x) {
    return fract(sin(x * 127.1 + seed * 17.23) * 43758.5453);
}

// sample small noise texture in a tiled way
float texnoise(vec2 p) {
    return texture(noise_tex, fract(p)).r;
}

// radial blob function
float blob(vec2 p, vec2 c, float r) {
    return smoothstep(r, r - r * 0.6, length(p - c));
}

void fragment() {
    // UV centered -0.5..0.5
    vec2 uv = UV - vec2(0.5);
    // keep aspect equal
    uv *= vec2(1.0, 1.0);
    float r = length(uv);

    // angle-based edge jitter (1D noise sampled from tiny texture)
    float ang = atan(uv.y, uv.x);
    float acoord = (ang + 3.14159) / (6.28318); // 0..1
    float n = texnoise(vec2(acoord * noise_scale, seed * 0.37));
    float jitter = (n - 0.5) * 0.45 * edge_rough;

    // base radius (controls overall size inside sprite quad)
    float base_r = 0.36;

    // radial threshold with jagged outline
    float rim_r = base_r + jitter;
    float thickness = 0.12;
    float shape = smoothstep(rim_r, rim_r - thickness, r);

    // add droplets: pseudo-random small blobs around center
    float drops = 0.0;
    for (int i = 0; i < droplets; i++) {
        // cheap deterministic offsets from seed
        float fi = float(i) * 12.7;
        float ox = hash(fi + 1.13) - 0.5;
        float oy = hash(fi + 3.21) - 0.5;
        vec2 off = vec2(ox, oy) * vec2(0.6, 0.6);
        float rr = 0.03 + hash(fi + 7.0) * 0.12;
        drops += blob(uv, off, rr) * smoothstep(1.0, 0.0, length(off) * 1.6);
    }

    // combine main shape + droplets
    float mask = clamp(shape + drops * 0.95, 0.0, 1.0);

    // color variation: subtle hue shift per seed
    vec3 base_col = splat_color.rgb;
    float hue_offset = (hash(seed * 3.14) - 0.5) * 0.18;
    // cheap tint by shifting channels
    vec3 tint = vec3(base_col.r + hue_offset * 0.6, base_col.g - hue_offset * 0.25, base_col.b - hue_offset * 0.35);
    tint = clamp(tint, 0.0, 1.0);

    // center darker / shading
    float center = smoothstep(0.0, base_r * 0.6, r);
    vec3 shaded = mix(tint * 1.06, tint * 0.6, center);

    // glossy highlight (additive)
    float highlight = smoothstep(base_r * 0.2, 0.0, r) * 0.6;

    vec3 final_col = shaded + vec3(highlight);

    COLOR = vec4(final_col, splat_color.a * mask);
}
