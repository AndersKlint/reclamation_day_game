shader_type fog;

uniform float base_density : hint_range(0.0, 0.1, 0.0001) = 0.0225;
uniform float base_height = 3.0;
uniform float height_falloff : hint_range(0.1, 100.0, 0.1) = 12.0;
uniform vec4 fog_albedo : source_color = vec4(0.55, 0.6, 0.72, 1.0);

void fog() {
	DENSITY = base_density * exp(-max(WORLD_POSITION.y - base_height, 0.0) / height_falloff);
	ALBEDO = fog_albedo.rgb;
}
