shader_type canvas_item;

uniform sampler2D texture_albedo : hint_albedo;

void vertex() {
	// Pass-through
}

void fragment() {
	// Try sampling the built-in TEXTURE first (engine may bind the mesh texture there)
	vec4 t_builtin = vec4(0.0);
	#ifdef TEXTURE
		t_builtin = texture(TEXTURE, UV);
	#endif

	// Then sample the explicit uniform if provided
	vec4 t_uniform = texture(texture_albedo, UV);

	// Choose which one appears to contain meaningful data.
	// If built-in texture is non-zero alpha, prefer it; otherwise use uniform.
	vec4 chosen = t_builtin.a > 0.001 ? t_builtin : t_uniform;

	COLOR = chosen;
}