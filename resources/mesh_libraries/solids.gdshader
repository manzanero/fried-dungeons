shader_type spatial;
uniform bool is_in_view = true;
uniform float intensity : hint_range(0.0, 1.0, 0.001) = 1.0;

void fragment() {
	vec3 color = vec3(COLOR[0], COLOR[1], COLOR[2]) * intensity;
	if (is_in_view) {
		color.rgb = mix(
			pow(
				(color.rgb + vec3(0.055)) * (1.0 / (1.0 + 0.055)),
				vec3(2.4)
			),
			color.rgb.rgb * (1.0 / 12.92),
			lessThan(color.rgb,vec3(0.04045))
		);
		ALBEDO = color;
	} else {
		const mat3 Mat = mat3(
			vec3(0.393, 0.769, 0.189),
			vec3(0.349, 0.686, 0.168),
			vec3(0.272, 0.534, 0.131)
		);
		ALBEDO = color * Mat;
	}
}
