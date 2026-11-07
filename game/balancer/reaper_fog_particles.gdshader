shader_type particles;
render_mode disable_force, disable_velocity;

uniform float size_factor : hint_range(1.0, 8.0) = 1.0;
uniform float spawn_radius = 0.5;
uniform float spawn_inner_radius = 0.0;
uniform float spawn_height = 0.45;
uniform float spawn_height_jitter = 0.3;
uniform float rise_speed = 0.55;
uniform float outward_speed = 0.3;
uniform float sway = 0.08;
uniform float start_scale = 0.3;
uniform float end_scale = 0.55;
uniform float opacity = 1.0;
uniform float fade_in = 0.06;

float hash(float value) {
	value = fract(value * 0.1031);
	value *= value + 33.33;
	value *= value + value;
	return fract(value);
}

void start() {
	float seed = float(NUMBER) + float(RANDOM_SEED % 65536u);
	vec4 r1 = vec4(hash(seed + 1.0), hash(seed + 2.0), hash(seed + 3.0), hash(seed + 4.0));
	vec4 r2 = vec4(hash(seed + 5.0), hash(seed + 6.0), hash(seed + 7.0), hash(seed + 8.0));
	vec4 r3 = vec4(hash(seed + 9.0), hash(seed + 10.0), hash(seed + 11.0), hash(seed + 12.0));
	vec4 r4 = vec4(hash(seed + 13.0), hash(seed + 14.0), hash(seed + 15.0), hash(seed + 16.0));

	float angle = r1.x * TAU;
	float radius = mix(spawn_inner_radius, spawn_radius, sqrt(r1.y)) * size_factor;
	vec3 origin = vec3(cos(angle) * radius, (spawn_height + (r1.z - 0.5) * spawn_height_jitter) * size_factor, sin(angle) * radius);
	float shape_x = mix(start_scale, end_scale, r1.w) * size_factor * mix(0.4, 1.5, r2.x) * mix(0.8, 1.25, r2.y);
	float shape_y = mix(start_scale, end_scale, r1.w) * size_factor * mix(0.4, 1.5, r2.x) * mix(0.8, 1.25, r2.z);
	float drift_angle = angle + (r2.w - 0.5) * 3.2;

	TRANSFORM = mat4(1.0);
	TRANSFORM[3].xyz = origin;
	TRANSFORM[0][0] = shape_x;
	TRANSFORM[1][1] = shape_y;
	TRANSFORM[2][2] = (shape_x + shape_y) * 0.5;
	// Anchor to the emitter only at birth; afterwards particles stay where the body left them.
	TRANSFORM = EMISSION_TRANSFORM * TRANSFORM;

	// x: base drift angle, y: outward multiplier, z: lift multiplier, w: wander amplitude.
	USERDATA1 = vec4(drift_angle, mix(0.15, 1.3, pow(r3.x, 1.6)), mix(0.03, 1.0, pow(r3.y, 2.2)), (r3.z - 0.5) * 3.0);
	USERDATA2 = vec4(shape_x, shape_y, (r3.w - 0.5) * 1.6, r1.z * TAU);
	// x: age, y: sway amplitude, z: sway frequency, w: fade start.
	USERDATA3 = vec4(0.0, mix(0.5, 1.8, r4.x), mix(0.6, 1.6, r4.y), mix(0.5, 0.78, r4.z));
	// x: wander frequency, y: wander phase, z: wiggle, w: texture seed.
	USERDATA4 = vec4(mix(0.15, 0.75, r2.y), r4.w * TAU, mix(0.7, 1.4, r2.z), r1.w);
	USERDATA5 = vec4(EMISSION_TRANSFORM[3].y, size_factor, 0.0, 0.0);
	CUSTOM = vec4(USERDATA2.w, USERDATA4.w, 0.0, 0.0);
}

void process() {
	USERDATA3.x += DELTA;
	float age = USERDATA3.x;
	float life = clamp(age / max(LIFETIME, 0.001), 0.0, 1.0);
	float birth_size = USERDATA5.y;
	// Drift direction curves slowly, so puffs keep scattering outwards instead of orbiting in place.
	float drift_angle = USERDATA1.x + USERDATA1.w * sin(age * USERDATA4.x + USERDATA4.y);
	float spread = outward_speed * USERDATA1.y * birth_size * (0.35 + 1.3 * life);
	TRANSFORM[3].xz += vec2(cos(drift_angle), sin(drift_angle)) * spread * DELTA;
	float lift = rise_speed * USERDATA1.z * birth_size * (0.25 + 0.9 * life);
	TRANSFORM[3].y += lift * DELTA;
	float sway_phase = USERDATA4.y + age * 1.1 * USERDATA3.z;
	TRANSFORM[3].x += sin(sway_phase) * sway * birth_size * DELTA;
	TRANSFORM[3].z += cos(sway_phase * 0.83 + 1.7) * sway * birth_size * DELTA;
	float growth = mix(0.85, 1.5, life);
	TRANSFORM[0][0] = USERDATA2.x * growth;
	TRANSFORM[1][1] = USERDATA2.y * growth;
	TRANSFORM[2][2] = (USERDATA2.x + USERDATA2.y) * 0.5 * growth;
	CUSTOM.x = USERDATA2.w + age * USERDATA2.z;
	CUSTOM.y = USERDATA4.w;
	CUSTOM.z = life;
	CUSTOM.w = smoothstep(0.0, fade_in, age) * (1.0 - smoothstep(USERDATA3.w, 1.0, life)) * opacity;
}
