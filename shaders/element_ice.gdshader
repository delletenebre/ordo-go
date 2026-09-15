shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled;
uniform float strength = 1.0;
uniform float elapsed = 0.0;
uniform float solid = 0.0;
varying vec3 local;
void vertex() { local = VERTEX; }
void fragment() {
	float rim = pow(1.0-abs(dot(normalize(NORMAL),normalize(VIEW))),2.3);
	vec3 grid = abs(sin(local*vec3(25.0,31.0,22.0)+sin(local.yzx*13.0)));
	float cracks = 1.0-smoothstep(.035,.10,min(grid.x,min(grid.y,grid.z)));
	ALBEDO = mix(vec3(.22,.57,.76),vec3(.85,.98,1.0),rim*.7+cracks*.3);
	ROUGHNESS = .24;
	METALLIC = .13;
	EMISSION = vec3(.3,.7,.88)*(rim*.25+cracks*.12)*strength;
	ALPHA = mix(.12+rim*.48+cracks*.12,.70+rim*.18,solid)*strength;
}
