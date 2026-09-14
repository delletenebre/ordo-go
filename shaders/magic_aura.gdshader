shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;

uniform vec4 tint : source_color = vec4(0.45, 1.0, 0.72, 1.0);
uniform float cursed = 0.0;
uniform float clock = 0.0;
uniform float opacity = 1.0;
uniform int layer = 0;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
  vec2 i = floor(p), f = fract(p);
  f = f * f * (3.0 - 2.0 * f);
  return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x),
             mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}
void fragment() {
  vec2 p = (UV - 0.5) * 2.0;
  float density = 0.0;
  float bright = 0.0;
  if (layer == 0) {
    float r = length(p);
    float angle = atan(p.y, p.x);
    float swirl = noise(p * 4.0 + vec2(sin(clock * 0.5), cos(clock * 0.5)));
    float halo = exp(-pow((r - 0.49) * 5.5, 2.0));
    float arc = pow(0.5 + 0.5 * sin(angle * 3.0 - clock * 1.4 + swirl * 2.0), 5.0);
    float filament = exp(-pow((r - 0.49 - sin(angle * 3.0 - clock) * 0.025) * 65.0, 2.0));
    density = (halo * (0.24 + swirl * 0.28) + filament * arc * 0.72) * (1.0 - smoothstep(0.72, 0.98, r)) * mix(1.0, 1.4, cursed);
    bright = 0.8 + filament * arc * 2.7;
  } else if (layer == 1) {
    float height = 1.0 - UV.y;
    float flow = noise(vec2(p.x * 3.5 + sin(height * 6.0 - clock) * 0.65, height * 5.0 - clock * 0.65));
    float detail = noise(vec2(p.x * 8.0 + clock * 0.2, height * 9.0 - clock));
    float sides = exp(-pow((abs(p.x + sin(height * 5.0 - clock + flow * 2.0) * 0.22) - (0.48 - height * 0.17)) * mix(6.0, 3.8, cursed), 2.0));
    float envelope = smoothstep(0.0, 0.13, height) * (1.0 - smoothstep(0.4, 1.0, height));
    density = sides * envelope * smoothstep(0.22, 0.78, flow * 0.8 + detail * 0.2) * mix(0.60, 2.0, cursed);
    bright = 0.45 + smoothstep(0.58, 0.85, flow) * 1.8;
  } else {
    float r = length(p);
    float core = exp(-r * r * 38.0);
    density = core + exp(-r * r * 5.0) * 0.22;
    bright = 2.5;
  }
  vec3 ink = mix(tint.rgb, tint.rgb * 0.13, cursed);
  ALBEDO = ink;
  EMISSION = tint.rgb * bright * mix(1.0, 0.14, cursed);
  ALPHA = clamp(density * opacity, 0.0, 0.9);
}
