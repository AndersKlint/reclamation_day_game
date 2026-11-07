shader_type spatial;

uniform sampler2D albedo_texture : source_color, filter_nearest_mipmap;
uniform vec3 flesh_color : source_color = vec3(0.012, 0.013, 0.019);
uniform vec3 bone_color : source_color = vec3(0.66, 0.65, 0.60);
uniform float bone_start : hint_range(0.0, 1.0) = 0.34;
uniform float bone_end : hint_range(0.0, 1.0) = 0.62;

void fragment() {
	vec3 tex = texture(albedo_texture, UV).rgb;
	float luminance = max(tex.r, max(tex.g, tex.b));
	float bone = smoothstep(bone_start, bone_end, luminance);
	ALBEDO = mix(flesh_color, bone_color, bone);
	ROUGHNESS = mix(0.94, 0.68, bone);
	SPECULAR = 0.12;
	RIM = mix(0.16, 0.4, bone);
	RIM_TINT = 0.25;
	EMISSION = bone_color * bone * 0.05;
}
