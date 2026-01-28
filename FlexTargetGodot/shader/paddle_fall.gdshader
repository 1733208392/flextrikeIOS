shader_type canvas_item;

// Animation parameters
uniform float fall_progress : hint_range(0.0, 1.0) = 0.0;
uniform float rotation_angle : hint_range(-180.0, 180.0) = 0.0;
uniform float motion_blur_intensity : hint_range(0.0, 0.1) = 0.02;
uniform vec2 motion_direction = vec2(0.0, 1.0);

// Perspective and depth effects
uniform float perspective_strength : hint_range(0.0, 2.0) = 1.0;
uniform float depth_fade : hint_range(0.0, 1.0) = 0.8;
uniform float shadow_intensity : hint_range(0.0, 1.0) = 0.3;

void vertex() {
	// Get vertex offset from center
	vec2 vertex_offset = VERTEX;
	
	// Apply dramatic scaling based on fall progress
	float scale_factor = 1.0 - (fall_progress * 0.8);
	scale_factor = max(scale_factor, 0.15); // Prevent complete disappearance
	
	// Apply perspective compression (Y-axis foreshortening)
	float perspective_factor = 1.0 - (fall_progress * perspective_strength * 0.5);
	vertex_offset.y *= perspective_factor;
	
	// Apply overall scaling
	vertex_offset *= scale_factor;
	
	// Apply rotation
	if (fall_progress > 0.0) {
		float rot_rad = radians(rotation_angle * fall_progress);
		float cos_r = cos(rot_rad);
		float sin_r = sin(rot_rad);
		vec2 rotated;
		rotated.x = vertex_offset.x * cos_r - vertex_offset.y * sin_r;
		rotated.y = vertex_offset.x * sin_r + vertex_offset.y * cos_r;
		vertex_offset = rotated;
	}
	
	// Add skew for 3D tilt effect
	vertex_offset.x += vertex_offset.y * fall_progress * 0.2;
	
	VERTEX = vertex_offset;
}

void fragment() {
	vec2 base_uv = UV;
	vec4 base_color = texture(TEXTURE, base_uv);
	
	// Simple motion blur
	if (fall_progress > 0.0 && motion_blur_intensity > 0.0) {
		vec4 blur_color = vec4(0.0);
		float samples = 4.0;
		float blur_amount = motion_blur_intensity * fall_progress;
		
		for (float i = 0.0; i < samples; i++) {
			vec2 offset = motion_direction * blur_amount * (i - samples * 0.5) / samples;
			vec2 sample_uv = base_uv + offset;
			
			if (sample_uv.x >= 0.0 && sample_uv.x <= 1.0 && sample_uv.y >= 0.0 && sample_uv.y <= 1.0) {
				blur_color += texture(TEXTURE, sample_uv);
			}
		}
		base_color = blur_color / samples;
	}
	
	// Apply depth fading
	float fade_factor = 1.0 - (fall_progress * depth_fade);
	base_color.a *= fade_factor;
	
	// Apply shadow darkening
	float shadow_factor = 1.0 - (fall_progress * shadow_intensity);
	base_color.rgb *= shadow_factor;
	
	// Simple distance-based vignette
	vec2 center_dist = abs(UV - vec2(0.5));
	float vignette = 1.0 - (fall_progress * 0.4 * length(center_dist));
	base_color.rgb *= vignette;
	
	COLOR = base_color;
}
