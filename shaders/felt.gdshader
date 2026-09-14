shader_type spatial;
render_mode diffuse_burley, specular_disabled;
uniform vec4 wool_color : source_color = vec4(0.3, 0.6, 0.8, 1.0);
uniform sampler2D wool_detail : filter_linear_mipmap_anisotropic, repeat_enable;
uniform float fiber_scale = 0.32;
uniform float relief = 0.34;
varying vec3 local_position;
varying vec3 local_normal;
void vertex() {
  local_position = VERTEX;
  local_normal = NORMAL;
}
void fragment() {
  vec3 weights = pow(abs(local_normal), vec3(5.0));
  weights /= max(dot(weights, vec3(1.0)), 0.0001);
  float a = texture(wool_detail, local_position.yz * fiber_scale).r;
  float b = texture(wool_detail, local_position.xz * fiber_scale).r;
  float c = texture(wool_detail, local_position.xy * fiber_scale).r;
  float fiber = dot(vec3(a, b, c), weights);
  ALBEDO = wool_color.rgb * (0.65 + fiber * 0.8);
  // Screen derivatives respect mip filtering: no subpixel random shimmer.
  vec3 across = normalize(dFdx(VERTEX));
  vec3 down = normalize(dFdy(VERTEX));
  NORMAL = normalize(NORMAL - (across * dFdx(fiber) + down * dFdy(fiber)) * relief);
  ROUGHNESS = 1.0;
  SPECULAR = 0.0;
  RIM = 0.14;
  RIM_TINT = 0.8;
}
