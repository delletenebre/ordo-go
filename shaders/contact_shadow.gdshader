shader_type spatial;
render_mode unshaded, depth_draw_never, cull_disabled;
void fragment() {
  vec2 p = (UV - 0.5) * 2.0;
  ALBEDO = vec3(0.026, 0.022, 0.032);
  ALPHA = (1.0 - smoothstep(0.08, 0.98, length(p))) * 0.30;
}
