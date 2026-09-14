shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;
varying vec4 smoke_color;
varying float age;
varying float seed;
void vertex() { smoke_color = COLOR; age = INSTANCE_CUSTOM.x; seed = INSTANCE_CUSTOM.y; }
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
  vec2 i = floor(p), f = fract(p);
  f = f * f * (3.0 - 2.0 * f);
  return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0)), f.x), f.y);
}
void fragment() {
  vec2 p = (UV - 0.5) * 2.0;
  float cloud = noise(p * 2.8 + vec2(seed, age * 0.25));
  float detail = noise(p * 5.6 + seed * 3.0) * 0.16;
  float edge = length(p) + (cloud - 0.5) * 0.33 + detail;
  float density = 1.0 - smoothstep(0.20, 0.96, edge);
  float envelope = smoothstep(0.0, 0.16, age) * (1.0 - smoothstep(0.38, 1.0, age));
  float lighting = 0.84 + (1.0 - UV.y) * 0.28 + cloud * 0.15;
  ALBEDO = smoke_color.rgb * lighting;
  ALPHA = density * envelope * smoke_color.a;
}
