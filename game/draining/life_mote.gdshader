shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix;

uniform float emission_strength : hint_range(0.0, 12.0, 0.1) = 6.0;
uniform float rim_strength : hint_range(0.0, 12.0, 0.1) = 4.0;

varying vec4 mote;

void vertex() {
	mote = INSTANCE_CUSTOM;
	float dark = step(0.48, mote.x);
	float size = mix(0.075, 0.14, dark) * mix(0.85, 1.15, mote.y);
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	VERTEX.xy *= vec2(size, size * mix(1.35, 1.85, mote.z));
	float angle = (mote.y - 0.5) * 0.7;
	VERTEX.xy = mat2(vec2(cos(angle), sin(angle)), vec2(-sin(angle), cos(angle))) * VERTEX.xy;
}

void fragment() {
	vec2 point = UV * 2.0 - 1.0;
	float dark = step(0.48, mote.x);
	float bend = mix(-0.16, 0.16, mote.z);
	point.x -= bend * (abs(point.y + 0.2) - 0.2);
	float width = mix(0.48, 0.62, mote.y);
	float distance_to_edge = abs(point.x) / width + abs(point.y + 0.12) / mix(0.72, 0.98, step(-0.12, point.y)) - 1.0;
	float edge_aa = max(fwidth(distance_to_edge), 0.0001);
	float mask = 1.0 - smoothstep(-0.5 * edge_aa, 0.5 * edge_aa, distance_to_edge);
	float rim = smoothstep(-0.09 - 0.5 * edge_aa, -0.09 + 0.5 * edge_aa, distance_to_edge);
	vec3 pale = mix(vec3(0.62, 0.94, 0.88), vec3(0.92, 1.0, 0.96), mote.z);
	vec3 rim_color = vec3(0.22, 0.85, 0.72);
	ALBEDO = mix(pale, vec3(0.004, 0.007, 0.009), dark);
	EMISSION = mix(pale * emission_strength, rim_color * rim_strength * rim, dark);
	ALPHA = mask * mote.w;
}
