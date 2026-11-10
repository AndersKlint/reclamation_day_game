shader_type spatial;
render_mode cull_disabled, diffuse_lambert, specular_disabled;

varying vec3 crop_color;
varying float withering;

void vertex() {
	withering = INSTANCE_CUSTOM.r;
	float height_scale = mix(1.0, 0.5, withering);
	float root_height = VERTEX.y;
	VERTEX.y *= height_scale;
	VERTEX.xz += INSTANCE_CUSTOM.gb * root_height * root_height;
	NORMAL = normalize(vec3(NORMAL.x, (NORMAL.y - dot(NORMAL.xz, INSTANCE_CUSTOM.gb * 2.0 * root_height)) / height_scale, NORMAL.z));
	crop_color = COLOR.rgb;
}

void fragment() {
	vec3 dead_color = vec3(0.055, 0.035, 0.021) * mix(0.8, 1.2, crop_color.r);
	ALBEDO = mix(crop_color, dead_color, withering);
	ROUGHNESS = 1.0;
}
