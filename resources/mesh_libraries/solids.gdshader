shader_type spatial;
render_mode unshaded;
uniform bool is_in_view = true;
uniform float intensity : hint_range(0.0, 1.0, 0.01) = 1.0;


void fragment() {
	vec3 color = vec3(COLOR[0], COLOR[1], COLOR[2]) * intensity;
	float alpha = COLOR[3];
	
	if (is_in_view) {
		color.rgb = mix(
			pow((color.rgb + vec3(0.055)) * (1.0 / (1.0 + 0.055)), vec3(2.4)),
			color.rgb.rgb * (1.0 / 12.92),
			lessThan(color.rgb, vec3(0.04045))
		);
		
	} else {
		const mat3 mat = mat3(
			vec3(0.393, 0.769, 0.189),
			vec3(0.349, 0.686, 0.168),
			vec3(0.272, 0.534, 0.131)
		);
		color *= mat;
	}

	ALBEDO = vec3(color[0], color[1], color[2]);
}
