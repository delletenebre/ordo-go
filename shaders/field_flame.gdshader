shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix, depth_draw_never, shadows_disabled;
uniform sampler2D fire_atlas : source_color, filter_linear, repeat_disable;
uniform float elapsed = 0.0;
uniform float phase = 0.0;
uniform float strength = 0.0;
uniform float lean = 0.0;
float hash(vec2 p) { return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453); }
float noise(vec2 p) {
	vec2 i=floor(p),f=fract(p); f=f*f*(3.0-2.0*f);
	return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y);
}
vec4 flame_frame(float index,vec2 uv) {
	vec2 cell=vec2(mod(index,4.0),floor(index/4.0));
	return texture(fire_atlas,(cell+clamp(uv,vec2(.004),vec2(.996)))/4.0);
}
void fragment() {
	float h=1.0-UV.y;
	float time=elapsed*14.0+phase*5.3;
	float frame=mod(floor(time),16.0);
	vec2 uv=UV;
	// Advect fine folds upward between flipbook frames, with a fixed flame root.
	float curl=noise(vec2(UV.x*5.0,h*6.0-elapsed*3.6+phase))-.5;
	uv.x-=lean*h*h*.28+curl*h*.065;
	uv.y+=sin(h*11.0-elapsed*7.0+phase)*h*.012;
	vec4 a=flame_frame(frame,uv);
	vec4 b=flame_frame(mod(frame+1.0,16.0),uv);
	// Premultiplied interpolation avoids dark fringes at dissolving wisps.
	vec4 fire=mix(vec4(a.rgb*a.a,a.a),vec4(b.rgb*b.a,b.a),smoothstep(0.0,1.0,fract(time)));
	vec3 color=fire.rgb/max(fire.a,.001);
	float hot=max(color.r,max(color.g,color.b));
	float edge=smoothstep(.018,.23,hot)*smoothstep(.025,.10,h)*(1.0-smoothstep(.95,1.0,h));
	ALBEDO=color;
	EMISSION=color*.7;
	ALPHA=fire.a*edge*strength*.92;
}
