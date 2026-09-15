shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix, depth_draw_never, shadows_disabled;

uniform float elapsed = 0.0;

float hash(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float noise(vec2 p) {
	vec2 cell = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(cell), hash(cell + vec2(1.0, 0.0)), f.x),
		mix(hash(cell + vec2(0.0, 1.0)), hash(cell + vec2(1.0)), f.x), f.y);
}

float turbulence(vec2 p) {
	float value = noise(p) * 0.55;
	p = p * 2.03 + vec2(7.1, 3.7);
	value += noise(p) * 0.27;
	p = p * 2.01 + vec2(1.7, 9.2);
	value += noise(p) * 0.13;
	return value + noise(p * 2.02) * 0.05;
}

void fragment() {
	float h = 1.0 - UV.y;
	float x = UV.x * 2.0 - 1.0;
	float t = elapsed;
	// All scales travel upward. Larger eddies bend and tear the smaller ones.
	vec2 flow = vec2(x * 2.8, h * 3.0 - t * 1.65);
	float roll = turbulence(flow * 0.65 + vec2(0.0, t * 0.30));
	float bent_x = x + (roll - 0.5) * (0.18 + h * 0.65);
	float coarse = turbulence(vec2(bent_x * 3.6, h * 2.7 - t * 1.90) + (roll - 0.5) * 1.7);
	float detail = turbulence(vec2(bent_x * 7.5, h * 4.2 - t * 2.70));
	float taper = 1.12 - h * 1.30 - abs(bent_x) * (1.20 + h * 0.55);
	float density = taper + (coarse - 0.5) * (0.95 + h * 0.55) + (detail - 0.5) * 0.32;
	// Density drives both combustion color and opacity, leaving hollow curls
	// and short-lived detached wisps instead of solid, permanently lit tubes.
	float heat = clamp(density * 1.22, 0.0, 1.0);
	vec3 color = mix(vec3(0.72, 0.025, 0.002), vec3(1.0, 0.23, 0.008), smoothstep(0.0, 0.22, heat));
	color = mix(color, vec3(1.0, 0.66, 0.07), smoothstep(0.20, 0.56, heat));
	color = mix(color, vec3(1.0, 0.94, 0.59), smoothstep(0.50, 0.88, heat));
	float edge = smoothstep(0.0, 0.12, density);
	float base = smoothstep(0.005, 0.075, h);
	float top = 1.0 - smoothstep(0.90, 0.995, h);
	ALBEDO = color;
	EMISSION = color * (0.65 + heat * 0.65);
	float crystal_y = 0.10 + h*1.10;
	float crystal_width = min((crystal_y-0.07)/0.38,(1.24-crystal_y)/0.79)*1.159;
	float containment = 1.0-smoothstep(crystal_width-0.07,crystal_width,abs(x));
	ALPHA = edge * base * top * containment * 0.98;
}
