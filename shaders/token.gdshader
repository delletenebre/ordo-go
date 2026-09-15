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
  vec2 uv = (vec2(.5) + p.xz / (radius*2.0) * .80 + tile) * .5;
  vec3 cap = texture(caps,uv).rgb;
  float radial = length(p.xz)/radius;
  float top = smoothstep(.15,.65,n.y);
  vec3 weights = pow(abs(n),vec3(5.0));
  weights /= max(dot(weights,vec3(1.0)),.001);
  float fuzz = dot(vec3(texture(wool,p.yz*.7).r,
    texture(wool,p.xz*.7).r,texture(wool,p.xy*.7).r),weights);
  // Authored ivory wool binding and dyed felt face retain their separate colors.
  // Avoid uniform recoloring and luminous contour lines: these read as plastic.
  vec3 face = cap * 1.12;
  float binding_detail = max(cap.r,max(cap.g,cap.b));
  vec3 body = side_color.rgb * (.40+pow(binding_detail,.7)*.65) * (.80+fuzz*.35);
  body = mix(body,face,top);
  float glyph = smoothstep(.45,.75,min(cap.r,min(cap.g,cap.b)));
  glyph *= 1.0-smoothstep(.5,.65,radial);
  ALBEDO = body;
  float fiber = mix(fuzz,dot(cap,vec3(.2126,.7152,.0722)),top);
  NORMAL = normalize(NORMAL - (normalize(dFdx(VERTEX))*dFdx(fiber)
    + normalize(dFdy(VERTEX))*dFdy(fiber))*.65);
  EMISSION = cap*glyph*top*.10;
  ROUGHNESS = 1.0;
  SPECULAR = 0.0;
  RIM = .18; RIM_TINT = .8;
}
