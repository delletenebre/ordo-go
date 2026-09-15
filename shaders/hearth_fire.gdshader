shader_type spatial;
render_mode unshaded, cull_back, blend_mix, depth_draw_never, shadows_disabled;
uniform float elapsed = 0.0;
uniform float mend_glow = 0.0;
varying float height;
void vertex() {
	height = VERTEX.y;
}
void fragment() {
	float facing = abs(dot(normalize(NORMAL),normalize(VIEW)));
	float facet = 0.5 + 0.5*NORMAL.x;
	float warmth = 1.0-clamp(height/1.24,0.0,1.0);
	vec3 color = mix(vec3(1.0,0.38,0.035),vec3(1.0,0.73,0.25),facet*0.55+warmth*0.3);
	float pulse = 0.025*sin(elapsed*3.4-height*7.0);
	color = mix(color, vec3(1.0,0.9,0.6),mend_glow*0.65);
	ALBEDO = color;
	EMISSION = color*(0.60+warmth*0.20+pulse+mend_glow*1.5);
	ALPHA = 0.43+(1.0-facing)*0.23;
}
