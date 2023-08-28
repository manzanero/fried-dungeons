shader_type spatial;
render_mode unshaded;
render_mode depth_prepass_alpha;
render_mode depth_test_disabled;

uniform vec3 mouse_position;
uniform vec4 color : source_color = vec4(0.94, 0.54, 0.15, 1.0);

const float fade_distance = 2.5;
varying vec3 world_vertex;


void vertex() {
	world_vertex = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float d = length(vec2(mouse_position.x - world_vertex.x, mouse_position.z - world_vertex.z));
	float alpha = 1.0 - pow(smoothstep(0.5, fade_distance, d), 0.5);
	ALBEDO = color.rgb;
	ALPHA = alpha;
	
	if (alpha <= 0.0) {
		discard;
	}
}
