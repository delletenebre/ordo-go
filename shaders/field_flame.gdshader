shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix, depth_draw_never, shadows_disabled;
uniform float elapsed = 0.0;
uniform float phase = 0.0;
uniform float strength = 0.0;
uniform float lean = 0.0;
void vertex() {
	float h=UV.y;
	float t=elapsed+phase;
	float wave=sin(t*5.2-h*7.0);
	VERTEX.x+=h*h*(wave*.025+sin(t*8.1-h*10.0)*.012+lean*.30);
	VERTEX.y*=1.0+sin(t*6.3-h*8.0)*.065*h;
	VERTEX.z+=sin(t*4.1-h*6.2)*h*h*.018;
}
void fragment() {
	float face=abs(dot(normalize(NORMAL),normalize(VIEW)));
	float h=UV.y;
	float inner=1.0-smoothstep(.08,.40,abs(UV.x-.50+sin(h*7.0-elapsed*3.0+phase)*h*.04));
	inner*=1.0-smoothstep(.26,.73,h);
	vec3 color=mix(vec3(.78,.115,.02),vec3(1.0,.37,.045),smoothstep(.12,.84,face));
	color=mix(color,vec3(1.0,.74,.19),smoothstep(.20,.76,inner));
	color=mix(color,vec3(1.0,.90,.46),smoothstep(.82,1.0,inner));
	ALBEDO=color;
	EMISSION=color*.28;
	ALPHA=strength;
}
