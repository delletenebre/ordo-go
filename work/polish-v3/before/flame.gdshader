shader_type spatial;
render_mode unshaded, cull_disabled;
uniform vec4 tint : source_color = vec4(1.0, 0.4, 0.04, 1.0);
uniform float heat = 1.0;
void vertex() {
  float h = UV.y;
  VERTEX.x += sin(TIME * 1.8 + h * 4.0) * h * h * 0.035;
  VERTEX.z += cos(TIME * 1.5 + h * 3.0) * h * h * 0.023;
}
void fragment() {
  float facet = 0.68 + 0.32 * abs(dot(normalize(NORMAL), normalize(vec3(0.6,0.4,0.7))));
  float edge = pow(1.0 - abs(dot(normalize(NORMAL), normalize(VIEW))), 3.0);
  vec3 color = mix(tint.rgb * facet, vec3(1.0, 0.83, 0.38), UV.y * 0.26);
  color = mix(color, vec3(1.0, 0.90, 0.58), edge * 0.65);
  ALBEDO = color;
  EMISSION = color * heat;
}
