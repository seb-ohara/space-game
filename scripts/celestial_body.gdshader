shader_type canvas_item;
render_mode unshaded;

uniform sampler2D surface_noise : filter_linear_mipmap, repeat_enable;
uniform vec2 sunward = vec2(-1.0, 0.0);
uniform float disc_extent = 1.0;
uniform int body_kind = 0;

float crater(vec2 surface, vec2 center, float radius) {
	float distance_to_center = length(surface - center) / radius;
	return 0.20 * (smoothstep(0.68, 0.91, distance_to_center) - smoothstep(0.93, 1.15, distance_to_center))
		- 0.29 * (1.0 - smoothstep(0.63, 0.94, distance_to_center));
}

void fragment() {
	vec2 point = (UV * 2.0 - 1.0) * disc_extent;
	float distance_to_center = length(point);
	float edge_width = max(fwidth(distance_to_center), 0.0001);
	float disc = 1.0 - smoothstep(1.0 - edge_width, 1.0 + edge_width, distance_to_center);
	vec3 normal = vec3(point, sqrt(max(1.0 - dot(point, point), 0.0)));
	vec2 surface = point + normal.z * vec2(0.27, -0.19);
	if (body_kind == 0) {
		float halo = 0.0;
		vec3 corona = vec3(0.0);
		if (disc < 1.0 && distance_to_center < disc_extent) {
			vec2 direction = point / max(distance_to_center, 0.001);
			float filament = texture(surface_noise, direction * 0.29 + 0.5).r;
			halo = exp(-max(distance_to_center - 0.97, 0.0) * (5.0 + 6.0 * filament));
			halo *= (0.5 + 0.5 * filament) * (1.0 - smoothstep(1.8, disc_extent, distance_to_center));
			corona = mix(vec3(0.82, 0.18, 0.035), vec3(1.0, 0.68, 0.26), halo);
		}
		vec3 photosphere = vec3(0.0);
		if (disc > 0.0) {
			float terrain = texture(surface_noise, surface * 0.37 + vec2(0.42, 0.18)).r;
			float detail = texture(surface_noise, surface * 1.81 + vec2(0.14, 0.61)).r;
			float plasma = smoothstep(0.22, 0.8, terrain * 0.42 + detail * 0.58);
			photosphere = mix(vec3(0.97, 0.28, 0.045), vec3(1.0, 0.88, 0.49), plasma);
			photosphere = mix(photosphere, vec3(1.0, 0.94, 0.73), 0.45 * normal.z);
		}
		COLOR = vec4(mix(corona, photosphere, disc), max(disc, halo * 0.65));
	} else if (disc > 0.0 || (body_kind == 1 && distance_to_center < disc_extent)) {
		float light = dot(normal, normalize(vec3(sunward, 0.32)));
		float daylight = smoothstep(-0.08, 0.8, light);
		float rim = pow(1.0 - normal.z, 3.0) * smoothstep(-0.4, 0.72, light);
		float terrain = texture(surface_noise, surface * 0.37 + vec2(0.42, 0.18)).r;
		float detail = texture(surface_noise, surface * 1.81 + vec2(0.14, 0.61)).r;
		vec3 albedo;
		float atmosphere = 0.0;
		if (body_kind == 1) {
			float coast = terrain + (detail - 0.5) * 0.20;
			float land = smoothstep(0.51, 0.57, coast);
			vec3 ocean = mix(vec3(0.035, 0.16, 0.35), vec3(0.13, 0.48, 0.57), smoothstep(0.3, 0.55, coast));
			vec3 continent = mix(vec3(0.16, 0.43, 0.36), vec3(0.64, 0.55, 0.34), smoothstep(0.53, 0.83, coast));
			float vapor = texture(surface_noise, surface * vec2(0.46, 1.12) + vec2(0.59, 0.24)).r;
			float clouds = smoothstep(0.58, 0.77, vapor + (detail - 0.5) * 0.12);
			albedo = mix(mix(ocean, continent, land), vec3(0.76, 0.91, 0.92), 0.78 * clouds);
			albedo = mix(albedo, vec3(0.39, 0.83, 1.0), rim * 0.62);
			atmosphere = (1.0 - smoothstep(1.0, disc_extent, distance_to_center)) * rim * 0.55;
		} else {
			float rock = terrain * 0.6 + detail * 0.4;
			rock += crater(point, vec2(-0.33, -0.31), 0.25);
			rock += crater(point, vec2(0.21, 0.33), 0.18);
			rock += crater(point, vec2(0.57, -0.25), 0.12);
			rock += crater(point, vec2(-0.48, 0.46), 0.11);
			albedo = mix(vec3(0.27, 0.27, 0.35), vec3(0.82, 0.81, 0.78), clamp(rock, 0.0, 1.0));
		}
		vec3 lit_surface = albedo * mix(vec3(0.15, 0.21, 0.31), vec3(1.04, 0.99, 0.89), daylight);
		COLOR = vec4(mix(vec3(0.28, 0.65, 1.0), lit_surface, disc), max(disc, atmosphere));
	} else {
		COLOR = vec4(0.0);
	}
}
