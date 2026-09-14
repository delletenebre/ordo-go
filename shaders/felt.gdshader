shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;
uniform vec4 wool_color : source_color = vec4(0.3, 0.6, 0.8, 1.0);
uniform float fuzz = 0.12;
varying vec3 local_pos;
float hash(vec3 p) { return fract(sin(dot(p, vec3(127.1, 311.7, 74.7))) * 43758.5453); }
void vertex() { local_pos = VERTEX; }
void fragment() {
	float fiber = hash(floor(local_pos * 340.0));
	float weave = sin(local_pos.x * 190.0 + sin(local_pos.z * 130.0)) * sin(local_pos.z * 210.0);
	ALBEDO = wool_color.rgb * (0.87 + fiber * 0.22 + weave * 0.035);
	ROUGHNESS = 0.96;
	float rim = pow(1.0 - max(dot(NORMAL, VIEW), 0.0), 3.0);
	EMISSION = wool_color.rgb * rim * fuzz;
}
