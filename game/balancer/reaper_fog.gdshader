shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix;

uniform sampler2D smoke_texture : filter_linear_mipmap, repeat_enable;
uniform vec3 fog_color : source_color = vec3(0.010, 0.011, 0.017);
uniform vec3 fog_edge : source_color = vec3(0.11, 0.12, 0.17);
uniform float wisp_scale : hint_range(0.5, 3.0) = 1.0;
uniform float drift_speed : hint_range(0.0, 0.3) = 0.06;
uniform float erosion : hint_range(0.0, 1.0) = 0.55;

varying vec4 particle_data;

void vertex() {
	particle_data = INSTANCE_CUSTOM;
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(
		vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0),
		vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0),
		vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0),
		vec4(0.0, 0.0, 0.0, 1.0));
	float angle = particle_data.x;
	VERTEX.xy = mat2(vec2(cos(angle), sin(angle)), vec2(-sin(angle), cos(angle))) * VERTEX.xy;
}

void fragment() {
	vec2 point = UV * 2.0 - 1.0;
	float radius = length(point);
	float seed = particle_data.y;
	float age = particle_data.z;
	vec2 offset = vec2(seed, fract(seed * 7.31 + 0.19));
	vec2 direction = normalize(vec2(fract(seed * 11.3 + 0.37), fract(seed * 5.9 + 0.71)) - 0.5 + vec2(0.0001));
	// Texture motion runs on particle age, so no two puffs share the same scroll.
	vec2 drift = offset * 4.0 + direction * age * drift_speed * mix(0.5, 1.8, fract(seed * 2.3 + 0.53));
	float wisps = texture(smoke_texture, UV * wisp_scale * mix(0.85, 1.25, fract(seed * 3.7)) + drift).r;
	float mask = smoothstep(1.0, 0.12, radius + (wisps - 0.5) * 0.8 + smoothstep(0.45, 1.0, age) * erosion);
	if (mask * particle_data.w < 0.004) {
		discard;
	}
	ALBEDO = mix(fog_color, fog_edge, smoothstep(0.35, 1.0, radius) * 0.9);
	ALPHA = mask * particle_data.w;
}
