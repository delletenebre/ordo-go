shader_type spatial;
render_mode diffuse_burley, specular_disabled;
uniform sampler2D rug_map : source_color, filter_linear_mipmap_anisotropic;
uniform sampler2D wool_map : filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec4 dye : source_color = vec4(0.92,0.88,0.82,1.0);
varying vec3 cloth_position;
void vertex() {
  cloth_position = VERTEX;
  vec3 fiber = textureLod(rug_map,UV,1.0).rgb;
  // Raised ivory applique follows the actual authored pattern.
  float applique = smoothstep(0.10,0.38,min(fiber.r,min(fiber.g,fiber.b)));
  VERTEX.y += applique*0.035;
}
void fragment() {
  vec3 cloth = texture(rug_map,UV).rgb;
  float fiber = texture(wool_map,cloth_position.xz*0.6).r;
  float height = dot(cloth,vec3(0.22,0.65,0.13));
  ALBEDO = cloth*dye.rgb*(0.90+fiber*0.20);
  vec3 n = normalize(NORMAL);
  vec3 q0=dFdx(VERTEX), q1=dFdy(VERTEX);
  vec3 s=cross(q1,n), t=cross(n,q0);
  float determinant=dot(q0,s);
  vec3 gradient=sign(determinant)*(dFdx(height)*s+dFdy(height)*t);
  NORMAL=normalize(abs(determinant)*n-gradient*0.022);
  ROUGHNESS=1.0; SPECULAR=0.0; RIM=0.12; RIM_TINT=0.75;
}
