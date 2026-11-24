shader_type canvas_item;

// Coordinates are local to each rock, so its surface stays fixed as the camera moves.
uniform vec4 rock_color : source_color = vec4(0.34, 0.32, 0.29, 1.0);
uniform float rock_seed = 0.0;

float hash21(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7)) + rock_seed * 0.013) * 43758.5453);
}

float noise2(vec2 p) {
	vec2 cell = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash21(cell), hash21(cell + vec2(1.0, 0.0)), f.x),
		mix(hash21(cell + vec2(0.0, 1.0)), hash21(cell + vec2(1.0, 1.0)), f.x), f.y);
}

// Sparse, uneven depressions rather than a regular grid of circular dots.
vec2 crater_detail(vec2 p) {
	vec2 cell = floor(p);
	vec2 local = fract(p);
	float hollow = 0.0;
	float rim = 0.0;
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 id = cell + vec2(float(x), float(y));
			float chance = hash21(id + 42.0);
			vec2 center = vec2(hash21(id + 8.3), hash21(id + 19.7)) * 0.7 + 0.15;
			vec2 delta = local - vec2(float(x), float(y)) - center;
			float radius = mix(0.12, 0.30, hash21(id + 72.0));
			float distortion = (noise2(p * 4.0 + id) - 0.5) * 0.15;
			float distance_to_center = length(delta * vec2(1.0, 1.15)) + distortion;
			float enabled = step(0.48, chance);
			hollow = max(hollow, (1.0 - smoothstep(radius * 0.55, radius, distance_to_center)) * enabled);
			float ring = smoothstep(radius * 0.72, radius, distance_to_center) * (1.0 - smoothstep(radius, radius * 1.3, distance_to_center));
			rim = max(rim, ring * enabled * clamp(0.65 + (delta.x + delta.y) * 1.6, 0.0, 1.0));
		}
	}
	return vec2(hollow, rim);
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	vec2 offset = vec2(rock_seed * 0.017, rock_seed * 0.031);
	float broad = noise2(p * 3.0 + offset);
	float medium = noise2(p * 8.0 + offset + broad * 0.65);
	float grain = noise2(p * 27.0 + offset);
	vec2 craters = crater_detail(p * 3.1 + offset);

	// A soft upper-left light gives the surface volume without strong radial facets.
	float lighting = 0.96 - 0.20 * p.x - 0.24 * p.y - 0.12 * dot(p, p);
	float surface = (broad - 0.5) * 0.27 + (medium - 0.5) * 0.19 + (grain - 0.5) * 0.10;
	float shade = clamp(lighting + surface - craters.x * 0.19 + craters.y * 0.10, 0.48, 1.28);
	vec3 tint = mix(vec3(0.94, 0.97, 1.03), vec3(1.05, 1.02, 0.96), broad);
	COLOR = vec4(rock_color.rgb * tint * shade, rock_color.a);
}
