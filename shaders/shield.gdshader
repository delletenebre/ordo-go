shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;
uniform vec4 shield_color : source_color = vec4(1.0, 0.7, 0.25, 1.0);
void fragment() {
  float edge = pow(1.0 - abs(dot(NORMAL, VIEW)), 2.7);
  float ripple = 0.55 + 0.45 * sin(UV.y * 55.0 - TIME * 3.0);
  ALBEDO = shield_color.rgb;
  EMISSION = shield_color.rgb * 1.7;
  ALPHA = edge * 0.3 + ripple * 0.012;
}
