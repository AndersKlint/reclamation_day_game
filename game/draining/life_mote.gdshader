shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix;

uniform vec4 dark_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform vec4 white_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float emission_strength : hint_range(0.0, 8.0, 0.1) = 3.0;
uniform float size_scale : hint_range(0.1, 160.0, 0.5) = 1.0;
uniform float grain_scale : hint_range(1.0, 16.0, 0.5) = 6.0;

varying vec4 mote;

float hash21(vec2 point) {
	point = fract(point * vec2(123.34, 456.21));
	point += dot(point, point + 45.32);
	return fract(point.x * point.y);
}

float value_noise(vec2 point) {
	vec2 cell = floor(point);
	vec2 local = fract(point);
	vec2 blend = local * local * (3.0 - 2.0 * local);
	float a = hash21(cell);
	float b = hash21(cell + vec2(1.0, 0.0));
	float c = hash21(cell + vec2(0.0, 1.0));
	float d = hash21(cell + vec2(1.0, 1.0));
	return mix(mix(a, b, blend.x), mix(c, d, blend.x), blend.y);
}

void vertex() {
	mote = INSTANCE_CUSTOM;
	float pulse = 0.94 + 0.06 * sin(TIME * mix(1.5, 3.5, mote.x) + mote.z * TAU);
	float size = mix(0.0375, 0.07, step(0.48, mote.x)) * mix(0.8, 1.2, mote.y) * size_scale * pulse;
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	VERTEX.xy *= size * mix(0.55, 1.0, mote.w);
}

void fragment() {
	vec2 point = UV * 2.0 - 1.0;
	float radius = length(point);
	float edge_aa = max(fwidth(radius), 0.0005);

	float spin = mote.z * TAU;
	vec2 rotated = mat2(vec2(cos(spin), sin(spin)), vec2(-sin(spin), cos(spin))) * point;
	float grain = value_noise(rotated * grain_scale + mote.y * 17.0);
	float coarse = value_noise(rotated * grain_scale * 0.45 + mote.x * 29.0);

	float mask = 1.0 - smoothstep(0.94 - edge_aa, 1.0 + edge_aa, radius);
	float palette = fract(mote.y * 7.13 + mote.z * 3.71);
	vec3 particle_color = palette < 0.5 ? dark_color.rgb : white_color.rgb;
	particle_color = mix(particle_color, vec3(mix(0.01, 0.07, coarse)), 1.0 - step(0.5, palette));

	float glow = mix(0.35, 1.0, 1.0 - smoothstep(0.0, 1.0, radius));
	vec3 tinted = particle_color * glow * mix(0.55, 1.0, coarse) * mix(0.85, 1.0, grain);
	ALBEDO = tinted * 0.2;
	EMISSION = tinted * emission_strength;
	ALPHA = mask * mote.w;
}
