shader_type canvas_item;
render_mode unshaded, blend_premul_alpha;

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
	if (body_kind == 0 || body_kind == 3) {
		bool blue = body_kind == 3;
		vec3 radiance = vec3(0.0);
		if (disc < 1.0 && distance_to_center < disc_extent) {
			float altitude = max(distance_to_center - 1.0, 0.0);
			float corona = exp(-altitude * 9.0);
			float outer_glow = exp(-altitude * 2.65);
			float fade = 1.0 - smoothstep(1.45, disc_extent, distance_to_center);
			vec3 corona_color = blue ? vec3(0.10, 0.37, 0.75) : vec3(0.56, 0.26, 0.072);
			vec3 halo_color = blue ? vec3(0.024, 0.13, 0.32) : vec3(0.34, 0.125, 0.032);
			radiance = (corona_color * corona + halo_color * outer_glow) * fade * (1.0 - disc);
		}
		if (disc > 0.0) {
			float depth = sqrt(max(1.0 - dot(point, point), 0.0));
			vec2 surface = point + depth * vec2(0.27, -0.19);
			float terrain = texture(surface_noise, surface * 0.37 + vec2(0.42, 0.18)).r;
			float detail = texture(surface_noise, surface * 1.81 + vec2(0.14, 0.61)).r;
			float plasma = smoothstep(0.22, 0.8, terrain * 0.42 + detail * 0.58);
			vec3 surface_dark = blue ? vec3(0.26, 0.64, 1.0) : vec3(1.0, 0.51, 0.16);
			vec3 surface_light = blue ? vec3(0.76, 0.93, 1.0) : vec3(1.0, 0.88, 0.56);
			vec3 photosphere = mix(surface_dark, surface_light, 0.38 + 0.32 * plasma + 0.25 * depth);
			radiance += photosphere * disc;
		}
		COLOR = vec4(radiance, disc);
	} else if (disc > 0.0 || (body_kind != 2 && distance_to_center < disc_extent)) {
		vec3 normal = vec3(point, sqrt(max(1.0 - dot(point, point), 0.0)));
		vec2 surface = point + normal.z * vec2(0.27, -0.19);
		float light = dot(normal, normalize(vec3(sunward, 0.32)));
		float daylight = smoothstep(-0.08, 0.8, light);
		float rim = pow(1.0 - normal.z, 3.0) * smoothstep(-0.4, 0.72, light);
		float terrain = texture(surface_noise, surface * 0.37 + vec2(0.42, 0.18)).r;
		float detail = texture(surface_noise, surface * 1.81 + vec2(0.14, 0.61)).r;
		vec3 albedo;
		vec3 atmosphere_color = vec3(0.28, 0.65, 1.0);
		vec3 daylight_color = vec3(1.04, 0.99, 0.89);
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
		} else if (body_kind == 4) {
			float latitude = dot(surface, vec2(0.27, 0.96));
			float clouds = 0.5 + 0.33 * sin(latitude * 25.0 + terrain * 2.6) + 0.17 * sin(latitude * 61.0 + detail * 2.0);
			albedo = mix(vec3(0.44, 0.20, 0.15), vec3(0.98, 0.77, 0.53), smoothstep(0.12, 0.88, clouds));
			atmosphere_color = vec3(1.0, 0.65, 0.38);
		} else if (body_kind == 5) {
			float ice = smoothstep(0.30, 0.70, terrain * 0.76 + detail * 0.24);
			albedo = mix(vec3(0.28, 0.31, 0.64), vec3(0.81, 0.86, 0.97), ice);
			atmosphere_color = vec3(0.42, 0.72, 1.0);
			daylight_color = vec3(0.82, 0.94, 1.07);
		} else {
			float rock = terrain * 0.6 + detail * 0.4;
			rock += crater(point, vec2(-0.33, -0.31), 0.25);
			rock += crater(point, vec2(0.21, 0.33), 0.18);
			rock += crater(point, vec2(0.57, -0.25), 0.12);
			rock += crater(point, vec2(-0.48, 0.46), 0.11);
			albedo = mix(vec3(0.27, 0.27, 0.35), vec3(0.82, 0.81, 0.78), clamp(rock, 0.0, 1.0));
		}
		if (body_kind != 2) {
			atmosphere = (1.0 - smoothstep(1.0, disc_extent, distance_to_center)) * rim * 0.55;
		}
		vec3 lit_surface = albedo * mix(vec3(0.15, 0.21, 0.31), daylight_color, daylight);
		float opacity = max(disc, atmosphere);
		COLOR = vec4(mix(atmosphere_color, lit_surface, disc) * opacity, opacity);
	} else {
		COLOR = vec4(0.0);
	}
}
