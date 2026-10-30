shader_type spatial;

uniform sampler2D grass_texture : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D scorch_mask : filter_linear, repeat_disable;
uniform vec4 grass_color : source_color = vec4(0.57, 0.63, 0.48, 1.0);
uniform float grass_roughness = 0.95;
uniform float scorch_strength : hint_range(0.0, 1.0) = 1.0;
varying vec2 ground_position;

void vertex() {
	ground_position = VERTEX.xz;
}

void fragment() {
	vec3 grass = texture(grass_texture, UV).rgb * grass_color.rgb;
	vec2 mask_uv = (ground_position + vec2(200.0, 250.0)) / vec2(400.0, 500.0);
	vec2 texel = 0.5 / vec2(textureSize(scorch_mask, 0));
	float mask = texture(scorch_mask, mask_uv).r * 0.4;
	mask += texture(scorch_mask, mask_uv + vec2(texel.x, 0.0)).r * 0.15;
	mask += texture(scorch_mask, mask_uv - vec2(texel.x, 0.0)).r * 0.15;
	mask += texture(scorch_mask, mask_uv + vec2(0.0, texel.y)).r * 0.15;
	mask += texture(scorch_mask, mask_uv - vec2(0.0, texel.y)).r * 0.15;
	float gray = dot(grass, vec3(0.299, 0.587, 0.114));
	vec3 charred = mix(grass, vec3(gray), 0.8) * vec3(0.28, 0.25, 0.22);
	ALBEDO = mix(grass, charred, mask * scorch_strength);
	ROUGHNESS = grass_roughness;
}
