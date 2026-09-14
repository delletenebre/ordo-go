shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;
uniform sampler2D soot_map : filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec3 map_offset;
uniform float surface_scale=1.0;
uniform vec4 ash_tint : source_color = vec4(0.35,0.37,0.43,1.0);
varying vec3 object_p;
varying vec3 object_n;
vec3 hash3(vec3 p) {
 return fract(sin(vec3(dot(p,vec3(127.1,311.7,74.7)),dot(p,vec3(269.5,183.3,246.1)),dot(p,vec3(113.5,271.9,124.6))))*43758.5453);
}
vec2 carbon(vec3 p) {
 vec3 cell=floor(p), f=fract(p); float first=9.0, second=9.0;
 for(int z=-1;z<=1;z++) for(int y=-1;y<=1;y++) for(int x=-1;x<=1;x++) {
  vec3 offset=vec3(float(x),float(y),float(z));
  vec3 delta=offset+hash3(cell+offset)*0.78+0.11-f;
  float d=dot(delta,delta);
  if(d<first){second=first;first=d;} else {second=min(second,d);}
 }
 return vec2(sqrt(first),sqrt(second)-sqrt(first));
}
void vertex(){object_p=VERTEX*surface_scale;object_n=NORMAL;}
void fragment(){
 vec3 w=pow(abs(object_n),vec3(4.0));w/=max(dot(w,vec3(1.0)),0.001);
 vec3 p=object_p*1.8+map_offset;
 float texture_value=dot(texture(soot_map,p.yz).rgb,vec3(.333))*w.x+dot(texture(soot_map,p.xz).rgb,vec3(.333))*w.y+dot(texture(soot_map,p.xy).rgb,vec3(.333))*w.z;
 vec2 plate=carbon(object_p*13.0+map_offset);
 float aa=max(fwidth(plate.y)*.65,.007);
 float raised=smoothstep(.018-aa,.085+aa,plate.y);
 float ash=pow(1.0-plate.x,3.0)*raised;
 ALBEDO=(vec3(.012,.015,.02)+texture_value*vec3(.22,.24,.27))*(.72+raised*.28);
 ALBEDO+=ash_tint.rgb*texture_value*.045;
 float height=raised*.04+texture_value*.65;
 vec3 n=normalize(NORMAL);
 vec3 q0=dFdx(VERTEX),q1=dFdy(VERTEX);
 vec3 s=cross(q1,n),t=cross(n,q0);
 float determinant=dot(q0,s);
 vec3 gradient=sign(determinant)*(dFdx(height)*s+dFdy(height)*t);
 NORMAL=normalize(abs(determinant)*n-gradient*.009);
 ROUGHNESS=.84;SPECULAR=.26;RIM=.16;RIM_TINT=.4;
}
