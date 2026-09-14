shader_type spatial;
render_mode diffuse_burley, specular_disabled;
uniform sampler2D caps : source_color, filter_linear_mipmap_anisotropic;
uniform sampler2D wool : filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec4 side_color : source_color;
uniform int slot = 0;
uniform float radius = 0.43;
varying vec3 p;
varying vec3 n;
void vertex() { p = VERTEX; n = NORMAL; }
void fragment() {
  vec2 tile = vec2(float(slot % 2),float(slot / 2));
  vec2 uv = (vec2(0.5) + p.xz / (radius*2.0) * 0.80 + tile) * 0.5;
  vec3 cap = texture(caps,uv).rgb;
  vec3 weights=pow(abs(n),vec3(5.0));weights/=max(dot(weights,vec3(1.0)),0.001);
  float fuzz=dot(vec3(texture(wool,p.yz*0.32).r,texture(wool,p.xz*0.32).r,texture(wool,p.xy*0.32).r),weights);
  float top = smoothstep(0.25,0.60,n.y);
  ALBEDO = mix(side_color.rgb*(0.65+fuzz*0.8),cap,top);
  float glyph=smoothstep(0.45,0.75,min(cap.r,min(cap.g,cap.b)))*(1.0-smoothstep(0.5,0.65,length(p.xz)/radius));
  EMISSION=cap*glyph*0.32*top;
  ROUGHNESS=1.0;SPECULAR=0.0;RIM=0.10;RIM_TINT=0.6;
}
