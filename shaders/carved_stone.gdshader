shader_type spatial;
render_mode diffuse_burley, specular_disabled;
uniform sampler2D rock_map : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec2 map_offset;
uniform vec4 rune_color : source_color = vec4(.7,.52,.28,1.0);
uniform float rune_glow=0.0;
varying vec2 stone_uv;
varying float carving;
void vertex(){stone_uv=VERTEX.xz*1.25+map_offset;carving=COLOR.r;}
void fragment(){
  vec3 rock=texture(rock_map,stone_uv).rgb;
  float grain=dot(rock,vec3(.22,.65,.13));
  vec3 sandstone=vec3(.27,.225,.18)*clamp(.6+grain*2.8,.5,1.35);
  ALBEDO=mix(sandstone,vec3(.025,.018,.013),carving*.94);
  EMISSION=rune_color.rgb*carving*rune_glow;
  ROUGHNESS=1.0;SPECULAR=0.0;
}
