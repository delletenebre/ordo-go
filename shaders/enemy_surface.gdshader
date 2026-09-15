shader_type spatial;
render_mode diffuse_burley,specular_schlick_ggx;
uniform sampler2D detail_map:source_color,filter_linear_mipmap_anisotropic,repeat_enable;
uniform vec4 base_color:source_color=vec4(.3,.35,.4,1.0);
uniform float ceramic=0.0;
uniform float map_scale=1.25;
uniform float death_fracture=0.0;
varying vec3 surface_p;
varying vec3 surface_n;
void vertex(){surface_p=VERTEX;surface_n=NORMAL;}
void fragment(){
 vec3 weights=pow(abs(surface_n),vec3(4.0));weights/=max(dot(weights,vec3(1.0)),.001);
 vec3 color=texture(detail_map,surface_p.yz*map_scale).rgb*weights.x+texture(detail_map,surface_p.xz*map_scale).rgb*weights.y+texture(detail_map,surface_p.xy*map_scale).rgb*weights.z;
 float grain=dot(color,vec3(.333));
 ALBEDO=mix(base_color.rgb*(.58+grain*3.0),color,ceramic)*(1.0-death_fracture*.22);
 vec3 across=normalize(dFdx(VERTEX)),down=normalize(dFdy(VERTEX));
 vec3 n=normalize(NORMAL),q0=dFdx(VERTEX),q1=dFdy(VERTEX);
 vec3 s=cross(q1,n),t=cross(n,q0);float determinant=dot(q0,s);
 vec3 gradient=sign(determinant)*(dFdx(grain)*s+dFdy(grain)*t);
 NORMAL=normalize(abs(determinant)*n-gradient*mix(.008,.003,ceramic));
 CLEARCOAT=ceramic*.28;CLEARCOAT_ROUGHNESS=.25;
 ROUGHNESS=mix(.67,.32,ceramic);SPECULAR=mix(.30,.42,ceramic);
 RIM=.10;RIM_TINT=.5;
}
