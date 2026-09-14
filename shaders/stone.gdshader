shader_type spatial;
render_mode diffuse_burley, specular_disabled;
uniform vec4 stone_color : source_color = vec4(0.5,0.49,0.47,1.0);
uniform sampler2D rock_color : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec3 map_offset;
varying vec3 local_p;
varying vec3 local_n;
varying vec3 view_x;
varying vec3 view_y;
varying vec3 view_z;
void vertex() {
  local_p = VERTEX * 1.15 + map_offset;
  local_n = NORMAL;
  view_x = (MODELVIEW_MATRIX * vec4(1.0,0.0,0.0,0.0)).xyz;
  view_y = (MODELVIEW_MATRIX * vec4(0.0,1.0,0.0,0.0)).xyz;
  view_z = (MODELVIEW_MATRIX * vec4(0.0,0.0,1.0,0.0)).xyz;
}
void fragment() {
  vec3 w = pow(abs(local_n),vec3(4.0)); w /= max(dot(w,vec3(1.0)),0.001);
  vec3 c = texture(rock_color,local_p.yz).rgb*w.x+texture(rock_color,local_p.xz).rgb*w.y+texture(rock_color,local_p.xy).rgb*w.z;
  float luma = dot(c,vec3(0.2126,0.7152,0.0722));
  ALBEDO = stone_color.rgb * clamp(0.55+luma*3.1,0.48,1.6);
  vec3 n=normalize(NORMAL);
  vec3 q0=dFdx(VERTEX),q1=dFdy(VERTEX);
  vec3 s=cross(q1,n),t=cross(n,q0);
  float determinant=dot(q0,s);
  vec3 gradient=sign(determinant)*(dFdx(luma)*s+dFdy(luma)*t);
  NORMAL=normalize(abs(determinant)*n-gradient*.008);
  ROUGHNESS = 0.96;
  SPECULAR = 0.0;
}
