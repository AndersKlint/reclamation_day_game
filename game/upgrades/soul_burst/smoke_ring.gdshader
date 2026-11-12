shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never, shadows_disabled;

uniform vec3 smoke_color : source_color = vec3(0.015, 0.015, 0.02);
uniform float opacity : hint_range(0.0, 1.0) = 0.9;
uniform float progress : hint_range(0.0, 1.0) = 0.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float value_noise(vec2 p) {
	vec2 cell = floor(p);
	vec2 local = fract(p);
	vec2 smooth_local = local * local * (3.0 - 2.0 * local);
	float a = hash(cell);
	float b = hash(cell + vec2(1.0, 0.0));
	float c = hash(cell + vec2(0.0, 1.0));
	float d = hash(cell + vec2(1.0, 1.0));
	return mix(mix(a, b, smooth_local.x), mix(c, d, smooth_local.x), smooth_local.y);
}

float fbm(vec2 p) {
	float value = 0.0;
	float amplitude = 0.5;
	for (int i = 0; i < 3; i++) {
		value += value_noise(p) * amplitude;
		p = p * 2.07 + vec2(13.0, 7.0);
		amplitude *= 0.5;
	}
	return value;
}

void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(
		vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0),
		vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0),
		vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0),
		vec4(0.0, 0.0, 0.0, 1.0));
	MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
}

void fragment() {
	vec2 centered = UV - vec2(0.5);
	float distance_from_center = length(centered);
	float seed = dot(MODEL_MATRIX[3].xz, vec2(3.71, 5.13)) + MODEL_MATRIX[3].y * 1.7;
	vec2 flow = centered * 2.8 + vec2(seed, seed * 0.7 + progress * 0.9);
	float billow = fbm(flow + fbm(flow * 1.6) * 0.55);
	float ragged_edge = distance_from_center + (billow - 0.5) * 0.32;
	float body = 1.0 - smoothstep(0.16, 0.5, ragged_edge);
	float density = smoothstep(0.3, 0.8, billow);
	float fade = smoothstep(0.0, 0.1, progress) * (1.0 - smoothstep(0.5, 1.0, progress));
	ALBEDO = mix(smoke_color * 0.5, smoke_color, density);
	ALPHA = clamp(body * (0.45 + 0.55 * density) * fade * opacity, 0.0, 1.0);
}
