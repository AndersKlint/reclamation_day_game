shader_type particles;
render_mode disable_force, disable_velocity;

uniform vec3 source_position = vec3(0.0);
uniform vec3 collector_position = vec3(0.0);
uniform float source_radius = 0.5;
uniform float travel_seconds = 1.0;

float hash(float value) {
	return fract(sin(value * 127.1 + 311.7) * 43758.5453);
}

void start() {
	float seed = float(NUMBER) + float(RANDOM_SEED % 65536u);
	// Custom particle shaders receive AMOUNT_RATIO without automatic birth rejection.
	ACTIVE = hash(seed + 7.0) < AMOUNT_RATIO;
	float angle = hash(seed) * TAU;
	float height = hash(seed + 2.0) * 2.0 - 1.0;
	vec3 offset = vec3(cos(angle) * sqrt(1.0 - height * height), height,
		sin(angle) * sqrt(1.0 - height * height));
	USERDATA1 = vec4(source_position + offset * source_radius * sqrt(hash(seed + 3.0)), 0.0);
	USERDATA2 = vec4(hash(seed + 4.0), hash(seed + 5.0), hash(seed + 6.0), 0.0);
	CUSTOM = vec4(USERDATA2.xyz, 0.0);
	TRANSFORM = mat4(1.0);
	TRANSFORM[3].xyz = USERDATA1.xyz;
}

void process() {
	USERDATA1.w += DELTA / max(travel_seconds, 0.1);
	float progress = clamp(USERDATA1.w, 0.0, 1.0);
	vec3 path = collector_position - USERDATA1.xyz;
	vec3 direction = normalize(path + vec3(0.0001));
	vec3 side = normalize(cross(direction, abs(direction.y) > 0.95 ? vec3(1.0, 0.0, 0.0) : vec3(0.0, 1.0, 0.0)));
	vec3 up = cross(side, direction);
	float phase = USERDATA2.x * TAU + progress * TAU * 1.4;
	float envelope = sin(progress * PI);
	float curl = envelope * min(length(path) * 0.18, 0.75);
	TRANSFORM[3].xyz = mix(USERDATA1.xyz, collector_position, progress)
		+ curl * (side * sin(phase) + up * cos(phase) * 0.65);
	CUSTOM.w = smoothstep(0.0, 0.09, progress) * (1.0 - smoothstep(0.8, 1.0, progress));
	if (USERDATA1.w >= 1.0) {
		ACTIVE = false;
	}
}
