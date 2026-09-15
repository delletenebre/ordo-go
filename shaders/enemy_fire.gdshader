shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix, depth_draw_never, shadows_disabled;
uniform float elapsed=0.0;
uniform float phase=0.0;
uniform float strength=0.0;
uniform vec2 drift=vec2(0.0);

float hash(vec2 p) { return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453); }
float noise(vec2 p) {
	vec2 cell=floor(p),f=fract(p); f=f*f*(3.0-2.0*f);
	return mix(mix(hash(cell),hash(cell+vec2(1,0)),f.x),mix(hash(cell+vec2(0,1)),hash(cell+vec2(1,1)),f.x),f.y);
}
float turbulence(vec2 p) {
	return noise(p)*.57+noise(p*2.03+7.1)*.28+noise(p*4.11+13.7)*.15;
}
void vertex() {
	float h=1.0-UV.y;
	VERTEX.x+=drift.x*h*h;
	VERTEX.z+=drift.y*h*h;
}
void fragment() {
	float h=1.0-UV.y;
	float x=(UV.x-.5)*2.0;
	float t=elapsed+phase;
	float curl=turbulence(vec2(x*2.0,h*2.2-t*1.8));
	float bent=x+(curl-.5)*(.22+h*.85);
	float billow=turbulence(vec2(bent*3.2,h*3.6-t*2.3));
	float fine=turbulence(vec2(bent*8.0,h*7.0-t*3.2));
	float taper=1.05-h*1.2-abs(bent)*(1.05+h*.75);
	float density=taper+(billow-.5)*1.1+(fine-.5)*.26;
	float fire=clamp(density*1.20,0.0,1.0);
	vec3 color=mix(vec3(.74,.025,.002),vec3(1.0,.22,.008),smoothstep(.0,.24,fire));
	color=mix(color,vec3(1.0,.68,.12),smoothstep(.24,.59,fire));
	color=mix(color,vec3(1.0,.94,.67),smoothstep(.55,.93,fire));
	ALBEDO=color;
	EMISSION=color*(.50+fire*.45);
	ALPHA=smoothstep(.0,.12,density)*smoothstep(0.0,.085,h)*(1.0-smoothstep(.92,1.0,h))*strength*.92;
}
