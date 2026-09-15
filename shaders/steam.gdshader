shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;
varying vec4 tint;
varying float age;
varying float seed;
void vertex() { tint = COLOR; age = INSTANCE_CUSTOM.x; seed = INSTANCE_CUSTOM.y; }
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1,311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 cell = floor(p), f = fract(p); f = f*f*(3.0-2.0*f);
	return mix(mix(hash(cell),hash(cell+vec2(1,0)),f.x),mix(hash(cell+vec2(0,1)),hash(cell+vec2(1)),f.x),f.y);
}
void fragment() {
	vec2 p = (UV-.5)*2.0;
	vec2 curl = vec2(noise(p*2.7+seed+age*.6),noise(p*2.7-seed-age*.4))-.5;
	float large = noise(p*3.1+curl*.8+vec2(seed,-age*.9));
	float fine = noise(p*7.4+curl+vec2(seed,age*1.1));
	float edge = length(p)+(.5-large)*.36;
	float cloud = (1.0-smoothstep(.08,.98,edge)) * (.72+large*.25+fine*.12);
	float fade = smoothstep(.0,.06,age)*(1.0-smoothstep(.23,1.0,age));
	vec3 white = mix(tint.rgb,vec3(.83,.90,.95),smoothstep(.04,.38,age));
	ALBEDO = white * (.72+large*.32+(1.0-UV.y)*.10);
	EMISSION = white*.025*(1.0-age);
	ALPHA = cloud * fade * tint.a;
}
