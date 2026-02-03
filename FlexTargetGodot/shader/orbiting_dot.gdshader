shader_type canvas_item;

uniform float radius = 150.0;
uniform float circle_thickness = 8.0;
uniform float dot_size = 12.0;
uniform vec3 circle_color = vec3(1.0, 0.4, 0.2); // Orange color
uniform vec3 dot_color = vec3(1.0, 1.0, 1.0); // White color
uniform float glow_intensity = 2.0;
uniform float time_scale = 1.0;

void fragment() {
	// Get the center coordinates (0.5, 0.5)
	vec2 center = vec2(0.5);
	vec2 pixel_pos = UV;
	
	// Calculate distance from center
	vec2 to_center = pixel_pos - center;
	float dist_from_center = length(to_center);
	
	// Calculate angle to current pixel
	float angle = atan(to_center.y, to_center.x);
	
	// Animate the dot position
	float dot_angle = TIME * time_scale;
	
	// Draw the circle
	float circle_dist = abs(dist_from_center - (radius / 1200.0)); // Normalize radius
	float circle = 1.0 - smoothstep(circle_thickness / 1200.0, circle_thickness / 1200.0 + 0.01, circle_dist);
	
	// Draw the orbiting dot
	vec2 dot_pos = center + vec2(cos(dot_angle), sin(dot_angle)) * (radius / 1200.0);
	float dot_dist = distance(pixel_pos, dot_pos);
	float dot = 1.0 - smoothstep(dot_size / 1200.0, dot_size / 1200.0 + 0.01, dot_dist);
	
	// Add glow to the dot with multiple layers
	float dot_glow_inner = exp(-dot_dist * 800.0) * glow_intensity * 0.8;
	float dot_glow_mid = exp(-dot_dist * 400.0) * glow_intensity * 0.5;
	float dot_glow_outer = exp(-dot_dist * 150.0) * glow_intensity * 0.2;
	float dot_glow = dot_glow_inner + dot_glow_mid + dot_glow_outer;
	
	// Combine circle and dot
	vec3 color = vec3(0.0);
	
	// Draw circle
	color = mix(color, circle_color, circle);
	
	// Draw dot with enhanced glow
	color = mix(color, dot_color, dot);
	color += dot_color * dot_glow;
	
	COLOR = vec4(color, max(circle, max(dot, dot_glow)));
}
