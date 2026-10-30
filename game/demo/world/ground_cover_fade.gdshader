shader_type spatial;
render_mode cull_disabled;

uniform vec4 base_color : source_color = vec4(1.0);
uniform sampler2D albedo_texture : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D albedo_texture_nearest : source_color, filter_nearest_mipmap, repeat_enable;
uniform bool nearest_filter = false;
uniform bool vertex_color = false;
uniform vec3 uv_scale = vec3(1.0);
uniform vec3 uv_offset = vec3(0.0);
uniform float alpha_cutoff = 0.0;
uniform float roughness = 1.0;
uniform float metallic = 0.0;
instance uniform float patch_opacity : hint_range(0.0, 1.0) = 1.0;

void fragment() {
	vec2 uv = UV * uv_scale.xy + uv_offset.xy;
	vec4 texel = nearest_filter ? texture(albedo_texture_nearest, uv) : texture(albedo_texture, uv);
	vec4 color = base_color * texel;
	if (vertex_color) {
		color *= COLOR;
	}
	if (color.a < alpha_cutoff) {
		discard;
	}
	ALBEDO = color.rgb;
	ROUGHNESS = roughness;
	METALLIC = metallic;
	ALPHA = patch_opacity;
	ALPHA_HASH_SCALE = 1.0;
}
