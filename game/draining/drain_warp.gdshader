shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;
uniform float strength_pixels : hint_range(0.0, 2.0) = 0.65;

void vertex() {
	float size = length(MODEL_MATRIX[0].xyz);
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0] * size, INV_VIEW_MATRIX[1] * size, INV_VIEW_MATRIX[2] * size, MODEL_MATRIX[3]);
}

void fragment() {
	vec2 point = UV * 2.0 - 1.0;
	float radius = length(point);
	float fade = (1.0 - smoothstep(0.25, 1.0, radius)) * smoothstep(0.0, 0.15, radius);
	vec2 direction = vec2(-point.y, point.x) * sin(radius * 17.0 - TIME * 2.0);
	vec2 offset = direction * fade * clamp(strength_pixels, 0.0, 2.0) / VIEWPORT_SIZE;
	ALBEDO = texture(screen_texture, clamp(SCREEN_UV + offset, vec2(0.001), vec2(0.999))).rgb;
	ALPHA = fade * 0.22;
}
