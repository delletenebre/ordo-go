shader_type canvas_item;
render_mode unshaded, blend_add;

uniform vec2 body_size = vec2(510.0,110.0);
uniform float padding = 52.0;
uniform float clock = 0.0;
uniform float strength = 1.0;
uniform float seed = 0.0;
uniform vec4 flare_a = vec4(0.0,0.0,2.0,0.0);
uniform vec4 flare_b = vec4(0.0,0.0,2.0,0.0);
uniform vec4 flare_c = vec4(0.0,0.0,2.0,0.0);

float hash(vec2 p) { return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453); }
float noise(vec2 p) {
	vec2 i=floor(p), f=fract(p); f=f*f*(3.0-2.0*f);
	return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y);
}
float flow(vec2 p) {
	return noise(p)*0.57+noise(p*2.03+7.1)*0.28+noise(p*4.07-3.7)*0.15;
}
float distance_to_rim(vec2 p) {
	float radius=min(body_size.x,body_size.y)*0.5-2.0;
	vec2 q=abs(p)-(body_size*0.5-vec2(radius));
	return length(max(q,vec2(0)))+min(max(q.x,q.y),0.0)-radius;
}
float burst(vec2 p,vec4 flare) {
	float age=flare.z;
	float envelope=smoothstep(0.0,0.13,age)*(1.0-smoothstep(0.22,1.0,age));
	vec2 delta=(p-flare.xy)/vec2(19.0,27.0);
	return exp(-dot(delta,delta))*envelope*flare.w;
}
void fragment() {
	vec2 p=UV*(body_size+vec2(padding*2.0))-(body_size*0.5+vec2(padding));
	float d=distance_to_rim(p);
	float time=clock+seed;
	// The noise travels upwards. Its roots remain attached to the physical rim.
	float eddy=flow(p*vec2(0.055,0.06)+vec2(-time*.7,time*2.7));
	float fine=noise(p*.25+vec2(time*1.2,time*4.8));
	float flares=burst(p,flare_a)+burst(p,flare_b)+burst(p,flare_c);
	float upper=1.0-smoothstep(-body_size.y*.25,body_size.y*.35,p.y);
	// Break up the roots so the wool remains visible between small flames.
	float fuel=smoothstep(.40,.72,flow(p*.085+vec2(time*.35,time*.65)));
	float lick=pow(eddy,2.8)*(7.0+upper*38.0+flares*22.0);
	float distorted=d+(eddy-.5)*3.4+(fine-.5)*1.2;
	float core_width=.6+eddy*.65+flares*.35;
	float core=exp(-pow(distorted/core_width,2.0))*(.10+fuel*.75);
	float outer=max(d,0.0);
	float tongue=(1.0-smoothstep(lick*.12,lick+1.0,outer))*smoothstep(-.5,1.5,d);
	tongue*=smoothstep(.44,.78,eddy+fine*.12)*(.2+fuel*.8)*(.25+upper*.75);
	float halo=exp(-abs(d)/7.0)*(.045+fuel*.08+flares*.05);
	float broad=exp(-abs(d)/19.0)*.016;
	// Additive local illumination also warms the wool just inside the rim.
	vec3 light=vec3(1.0,.14,.008)*(halo+broad);
	light+=mix(vec3(1.0,.17,.006),vec3(1.0,.52,.025),tongue)*tongue*.70;
	light+=mix(vec3(1.0,.35,.015),vec3(1.0,.76,.18),smoothstep(.4,1.0,core))*core*.65;
	float edge=1.0-smoothstep(padding-12.0,padding-2.0,outer);
	COLOR=vec4(light*strength*edge,1.0);
}
