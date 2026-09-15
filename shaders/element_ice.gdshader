shader_type spatial;
render_mode blend_mix, depth_prepass_alpha, cull_disabled;
uniform float strength = 1.0;
uniform float solid = 1.0;
varying vec3 local;
float hash(vec2 p) { return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453); }
float noise(vec2 p) {
	vec2 i=floor(p),f=fract(p); f=f*f*(3.0-2.0*f);
	return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y);
}
void vertex() { local=VERTEX; }
void fragment() {
	vec2 p=local.xz;
	float grain=noise(p*95.0);
	float cloud=noise(p*6.0)*.65+noise(p*15.0)*.35;
	float angle=atan(p.y,p.x);
	float radial=length(p);
	// Delicate branching frost grows inward from the edge, without a stamped icon.
	float sector=angle*12.0/6.2831853;
	float branch=abs(fract(sector+.06*sin(radial*15.0))-.5);
	float reach=.57+hash(vec2(floor(sector),2.0))*.22;
	float stem=(1.0-smoothstep(.006,.025,branch))*smoothstep(reach,reach+.12,radial);
	float twigs=1.0-smoothstep(.018,.055,abs(sin(radial*73.0+branch*55.0)));
	twigs*=1.0-smoothstep(.025,.16,branch);
	twigs*=smoothstep(reach+.05,reach+.18,radial);
	float edge=smoothstep(.68,.99,radial+cloud*.10);
	float frost=clamp(edge*(.45+grain*.42)+(stem+twigs*.52)*.52+smoothstep(.52,.80,cloud)*.35,0.0,1.0);
	vec3 blue=mix(vec3(.28,.59,.71),vec3(.59,.82,.88),cloud);
	ALBEDO=mix(blue,vec3(.88,.97,1.0),frost);
	ROUGHNESS=mix(.20,.73,frost);
	SPECULAR=.65;
	METALLIC=0.0;
	EMISSION=vec3(.23,.49,.58)*.08*strength;
	float alpha=mix(.16+frost*.76,.84+frost*.13,solid);
	ALPHA=alpha*strength;
}
