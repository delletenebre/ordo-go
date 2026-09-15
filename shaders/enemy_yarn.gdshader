shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

uniform sampler2D fiber_map : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec4 wool_color : source_color = vec4(.63,.54,.42,1.0);
uniform bool strand = true;
uniform float radius = 1.0;
uniform float heat = 0.0;
uniform float charred = 0.0;
uniform float elapsed = 0.0;
varying vec3 point;
varying vec3 surface_normal;

void vertex() { point=VERTEX/radius; surface_normal=NORMAL; }

void fragment() {
	vec3 w=pow(abs(surface_normal),vec3(4.0)); w/=max(dot(w,vec3(1.0)),.0001);
	float fibers;
	if(strand) {
		// UV runs along each twisted ply. Stretched real wool fibers follow it.
		fibers=texture(fiber_map,vec2(UV.x*.32,UV.y*1.8)).r;
	} else {
		fibers=dot(vec3(texture(fiber_map,point.yz*.8).r,texture(fiber_map,point.xz*.8).r,texture(fiber_map,point.xy*.8).r),w);
	}
	float nap=clamp(fibers*3.2,.36,1.6);
	vec3 base=wool_color.rgb*(.76+nap*.24);
	vec3 dx=dFdx(VERTEX),dy=dFdy(VERTEX);
	vec3 rx=cross(dy,NORMAL),ry=cross(NORMAL,dx);
	float det=dot(dx,rx);
	vec3 gradient=sign(det)*(dFdx(fibers)*rx+dFdy(fibers)*ry)/max(abs(det),.00001);
	NORMAL=normalize(NORMAL-gradient*(strand?.012:.020));
	// Smouldering stays on the surface and away from the central expression.
	float patch=texture(fiber_map,point.xz*1.6+point.y*.47).r;
	float exposed=smoothstep(.08,.55,point.y)*(1.0-smoothstep(.35,.90,point.z)*(1.0-smoothstep(.25,.68,abs(point.x))));
	float scorch=charred*exposed*smoothstep(.06,.21,patch);
	ALBEDO=mix(base,base*vec3(.12,.085,.055),scorch*.88);
	float coal=smoothstep(.15,.30,patch)*smoothstep(.035,.11,fibers)*exposed;
	float flicker=.74+.18*sin(elapsed*4.1+point.y*9.0)+.08*sin(elapsed*8.2+point.x*17.0);
	EMISSION=vec3(1.0,.19,.012)*coal*heat*flicker*.9;
	ROUGHNESS=.94;
	SPECULAR=.12;
	RIM=.22;
	RIM_TINT=.85;
}
