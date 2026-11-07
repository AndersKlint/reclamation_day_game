shader_type spatial;
render_mode cull_disabled;

uniform vec3 cloth_dark : source_color = vec3(0.006, 0.007, 0.012);
uniform vec3 cloth_light : source_color = vec3(0.028, 0.031, 0.048);
uniform float tatter_depth : hint_range(0.0, 0.4) = 0.2;
uniform float sway_strength : hint_range(0.0, 0.12) = 0.06;

float hash(vec2 point) {
	return fract(sin(dot(point, vec2(127.1, 311.7))) * 43758.5453);
}

float value_noise(vec2 point) {
	vec2 cell = floor(point);
	vec2 local = fract(point);
	vec2 smooth_local = local * local * (3.0 - 2.0 * local);
	return mix(
		mix(hash(cell), hash(cell + vec2(1.0, 0.0)), smooth_local.x),
		mix(hash(cell + vec2(0.0, 1.0)), hash(cell + vec2(1.0, 1.0)), smooth_local.x),
		smooth_local.y);
}

float fbm(vec2 point) {
	return 0.5 * value_noise(point) + 0.25 * value_noise(point * 2.03 + 1.7) + 0.125 * value_noise(point * 4.01 + 3.1);
}

void vertex() {
	float hem = UV.y * UV.y;
	VERTEX.x += sin(TIME * 1.1 + UV.x * 12.566 + 0.6) * sway_strength * hem;
	VERTEX.z += cos(TIME * 0.85 + UV.x * 12.566 + 1.9) * sway_strength * hem;
}

void fragment() {
	float grain = fbm(vec2(UV.x * 11.0, UV.y * 3.5));
	if (UV.y > 0.8 + grain * tatter_depth) {
		discard;
	}
	float fold = fbm(vec2(UV.x * 18.0, UV.y * 5.0) + 3.7);
	ALBEDO = mix(cloth_dark, cloth_light, 0.45 + fold * 0.55);
	ROUGHNESS = 0.96;
	SPECULAR = 0.1;
	RIM = 0.08 + UV.y * 0.3;
	RIM_TINT = 0.35;
}
