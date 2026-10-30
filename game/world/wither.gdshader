shader_type spatial;
render_mode cull_disabled;

uniform sampler2D albedo_texture : source_color, hint_default_white, filter_nearest_mipmap, repeat_enable;
uniform vec4 base_color : source_color = vec4(1.0);
uniform vec3 uv_scale = vec3(1.0);
uniform vec3 uv_offset = vec3(0.0);
uniform float alpha_scissor : hint_range(0.0, 1.0) = 0.001;
uniform float wither_amount : hint_range(0.0, 1.0) = 0.0;
uniform float freshening : hint_range(0.0, 1.0) = 0.0;
uniform float drain_flash : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	if (!FRONT_FACING) {
		NORMAL = -NORMAL;
	}
	vec4 source = texture(albedo_texture, UV * uv_scale.xy + uv_offset.xy) * base_color;
	float luminance = dot(source.rgb, vec3(0.299, 0.587, 0.114));
	vec3 dry = mix(source.rgb, vec3(luminance), 0.85) * vec3(0.52, 0.36, 0.23);
	vec3 fresh = source.rgb * vec3(0.9, 1.2, 0.78);
	ALBEDO = mix(mix(source.rgb, dry, wither_amount), fresh, freshening);
	ROUGHNESS = 1.0;
	EMISSION = vec3(0.35, 0.7, 0.65) * drain_flash;
	ALPHA = source.a;
	ALPHA_SCISSOR_THRESHOLD = alpha_scissor;
}
