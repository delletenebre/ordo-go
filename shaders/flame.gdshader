shader_type spatial;
render_mode unshaded, cull_disabled;
uniform vec4 tint : source_color = vec4(1.0, 0.4, 0.04, 1.0);
uniform float heat = 1.0;
void vertex() {
  float height = UV.y;
  VERTEX.x += sin(TIME * 4.7 + height * 5.0) * height * height * 0.08;
  VERTEX.z += cos(TIME * 3.9 + height * 4.0) * height * height * 0.05;
}
void fragment() {
  vec3 color = mix(tint.rgb, vec3(1.0, 0.88, 0.4), UV.y * 0.5);
  ALBEDO = color;
  EMISSION = color * heat;
}
