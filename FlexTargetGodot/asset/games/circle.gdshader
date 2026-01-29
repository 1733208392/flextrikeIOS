shader_type canvas_item;

void fragment() {
	vec2 uv = UV - vec2(0.5);
	float dist = length(uv);
	
	if (dist <= 0.5) {
		COLOR = vec4(1.0, 0.2, 0.2, 1.0);  // Red circle
	} else {
		COLOR.a = 0.0;  // Transparent outside circle
	}
}
