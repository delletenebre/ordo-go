shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_schlick_ggx;
uniform sampler2D grain_map : filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec4 bronze : source_color = vec4(.66,.40,.15,1.0);
varying vec3 local_p;
void vertex(){local_p=VERTEX;}
void fragment(){
 float grain=texture(grain_map,local_p.xy*2.3).r;
 float fine=texture(grain_map,local_p.xy*14.0).r;
 ALBEDO=bronze.rgb*(.65+grain*.65+fine*.10);
 vec3 dx=dFdx(VERTEX),dy=dFdy(VERTEX),n=normalize(NORMAL);
 vec3 rx=cross(dy,n),ry=cross(n,dx);float det=dot(dx,rx);
 NORMAL=normalize(n-sign(det)*(dFdx(fine)*rx+dFdy(fine)*ry)/max(abs(det),.00001)*.001);
 EMISSION=bronze.rgb*.15;
 METALLIC=.16;ROUGHNESS=.39+grain*.22;SPECULAR=.65;
}
