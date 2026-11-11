shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled;

uniform float radius = 1.0;
uniform float progress : hint_range(0.0, 1.0) = 1.0;
uniform vec4 wave_color : source_color = vec4(1.0, 0.78, 0.4, 1.0);

void fragment() {
	vec2 ground_position = (UV - vec2(0.5)) * 2.2 * radius;
	float distance_from_center = length(ground_position);
	float expansion = 1.0 - pow(1.0 - min(progress / 0.8, 1.0), 2.0);
	float wave_radius = max(radius * expansion, 0.01);
	float width = clamp(radius * 0.045, 0.12, 1.8);
	float edge_softness = max(fwidth(distance_from_center), width * 0.15);
	float ring_distance = abs(distance_from_center - wave_radius);
	float bright_ring = 1.0 - smoothstep(width * 0.35, width + edge_softness, ring_distance);
	float wake_distance = abs(distance_from_center - max(wave_radius - width * 2.8, 0.0));
	float wake = 1.0 - smoothstep(width * 0.3, width * 1.4 + edge_softness, wake_distance);
	float angle = atan(ground_position.y, ground_position.x);
	float breakup = 0.8 + 0.2 * sin(angle * 19.0 + distance_from_center * 4.0);
	float fade = 1.0 - smoothstep(0.6, 1.0, progress);
	float pulse_radius = min(radius * 0.3, 3.0) * (0.3 + min(progress * 6.0, 1.0));
	float pulse = (1.0 - smoothstep(0.0, max(pulse_radius, 0.01), distance_from_center));
	pulse *= pow(max(1.0 - progress * 4.0, 0.0), 2.0);
	float wave = (bright_ring + wake * 0.3) * breakup * fade;
	ALBEDO = mix(wave_color.rgb, vec3(1.0, 0.96, 0.8), clamp(bright_ring + pulse, 0.0, 1.0));
	ALPHA = clamp(wave * 0.9 + pulse * 0.85, 0.0, 0.95) * wave_color.a;
}
