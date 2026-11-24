shader_type canvas_item;
render_mode unshaded, blend_premul_alpha;

uniform sampler2D surface_noise : filter_linear_mipmap, repeat_enable;
uniform vec2 sunward = vec2(-1.0, 0.0);
uniform float disc_extent = 1.0;
uniform int body_kind = 0;

uniform int surface_style = -1;
uniform int stellar_style = -1;
uniform vec4 surface_dark : source_color = vec4(0.3, 0.3, 0.3, 1.0);
uniform vec4 surface_light : source_color = vec4(0.8, 0.8, 0.8, 1.0);
uniform vec4 atmosphere_color : source_color = vec4(0.3, 0.6, 1.0, 1.0);
uniform float atmosphere_strength;
uniform float surface_seed;
uniform float surface_scale = 1.0;
uniform float axis_angle;
uniform float ring_tilt;
uniform bool rings;

float crater(vec2 surface, vec2 center, float radius) {
	float distance_to_center = length(surface - center) / radius;
	return 0.20 * (smoothstep(0.68, 0.91, distance_to_center) - smoothstep(0.93, 1.15, distance_to_center))
		- 0.29 * (1.0 - smoothstep(0.63, 0.94, distance_to_center));
}

vec2 rotate_point(vec2 p, float angle) {
	return vec2(p.x * cos(angle) - p.y * sin(angle), p.x * sin(angle) + p.y * cos(angle));
}

vec4 star_model(vec2 point, float r, float disc) {
	float depth = sqrt(max(1.0 - dot(point, point), 0.0));
	vec2 seed = fract(surface_seed * vec2(0.61803, 0.38197));
	vec2 surface = (point + depth * vec2(0.15, -0.27)) * surface_scale;
	// Slow counter-flowing layers make the photosphere boil without changing
	// the seeded palette or the individual character of each star.
	float time = TIME * (0.0175 + fract(surface_seed * 0.17) * 0.0125);
	float coarse = texture(surface_noise, surface * 0.33 + seed + vec2(time, -time * 0.35)).r;
	float cells = texture(surface_noise, surface * 1.74 - seed + vec2(-time * 1.4, time * 0.8)).r;
	float angular = atan(point.y, point.x + 0.00001);
	vec2 rim = vec2(cos(angular), sin(angular));
	float flare = texture(surface_noise, rim * 0.51 + seed + vec2(time * 0.7, -time)).r;
	float tendrils = texture(surface_noise, rim * 1.15 - seed + vec2(-time, time * 0.6)).r;
	float alt = max(r - 1.0, 0.0);
	float taper = 1.0 - smoothstep(disc_extent * 0.68, disc_extent, r);
	bool compact = stellar_style == 12 || stellar_style == 13;
	bool giant = stellar_style >= 8 && stellar_style <= 11;
	float granules = smoothstep(0.27, 0.75, coarse * (giant ? 0.69 : 0.3) + cells * (giant ? 0.31 : 0.7));
	float spots = smoothstep(0.58, 0.82, coarse) * (stellar_style == 7 ? 0.45 : 0.20);
	vec3 surface_tint = mix(surface_dark.rgb, surface_light.rgb, 0.29 + granules * 0.56) * (0.70 + 0.30 * depth - spots);
	float pulse = 0.92 + 0.08 * sin(TIME * 0.35 + surface_seed);
	float corona = exp(-alt * (compact ? 8.0 : 5.0)) * (0.48 + 0.85 * flare);
	float halo = exp(-alt * 1.65) * (0.30 + flare * 0.22);
	float streamers = exp(-alt * 2.8) * pow(tendrils, 3.0) * 0.8;
	vec3 glow = atmosphere_color.rgb * (corona + halo + streamers) * taper * pulse;
	if (stellar_style == 13) {
		vec2 beam = rotate_point(point, surface_seed + sin(TIME * 0.34) * 0.4);
		float shaft = 1.0 - smoothstep(0.012, 0.25, abs(beam.y) / (0.5 + abs(beam.x) * 0.45));
		glow += vec3(0.46, 0.55, 1.0) * shaft * taper * (0.38 + 0.20 * sin(TIME * 3.5));
		surface_tint = mix(surface_tint, vec3(0.92, 0.96, 1.0), 0.57);
	}
	return vec4(mix(glow, surface_tint, disc), disc);
}

vec4 planet_model(vec2 point, float r, float disc) {
	vec3 normal = vec3(point, sqrt(max(1.0 - dot(point, point), 0.0)));
	vec2 surface = rotate_point(point + normal.z * vec2(0.27, -0.19), axis_angle) * surface_scale;
	vec2 seed = fract(surface_seed * vec2(0.61803, 0.38197));
	float rock = texture(surface_noise, surface * 0.43 + seed).r;
	float detail = texture(surface_noise, surface * 2.12 - seed).r;
	float fine = texture(surface_noise, surface * 5.3 + seed).r;
	float light = dot(normal, normalize(vec3(sunward, 0.26)));
	float day = smoothstep(-0.13, 0.85, light);
	float rim = pow(1.0 - normal.z, 2.8) * smoothstep(-0.47, 0.72, light);
	float value = smoothstep(0.25, 0.76, rock * 0.67 + detail * 0.33);
	vec3 low = surface_dark.rgb;
	vec3 high = surface_light.rgb;
	vec3 albedo = mix(low, high, value);
	vec3 emission = vec3(0.0);
	float vapor = texture(surface_noise, surface * vec2(0.69, 1.5) + seed.yx).r;
	if (surface_style == 0) {
		float coast = rock + 0.24 * (detail - 0.5);
		float ground = smoothstep(0.40, 0.45, coast) * (0.64 + value * 0.36);
		vec3 sea = mix(low * 0.32, atmosphere_color.rgb * 0.54, smoothstep(0.17, 0.50, coast));
		albedo = mix(sea, albedo, ground);
		albedo = mix(albedo, mix(high, vec3(0.9), 0.72), smoothstep(0.54, 0.77, vapor + fine * 0.1) * atmosphere_strength);
	} else if (surface_style == 1) {
		for (int i = 0; i < 9; i++) {
			float index = float(i) + surface_seed;
			vec2 center = (fract(sin(vec2(index, index + 83.1) * vec2(12.98, 78.23)) * 43758.5) - 0.5) * 1.85;
			value += crater(point, center, 0.052 + fract(index * 0.72) * 0.24);
		}
		albedo = mix(low, high, clamp(value, 0.0, 1.0));
	} else if (surface_style == 2) {
		float lat = surface.y;
		float storm = exp(-dot(surface - (seed - 0.5) * 1.1, (surface - (seed - 0.5) * 1.1) * vec2(8.0, 29.0)));
		float bands = 0.5 + sin(lat * (24.0 + seed.x * 17.0) + rock * 2.4 + storm * 3.3) * 0.27;
		bands += sin(lat * 65.0 + detail * 2.1) * 0.11 + (vapor - 0.5) * 0.36;
		albedo = mix(low, high, smoothstep(0.14, 0.92, bands));
		albedo = mix(albedo, high, storm * 0.26);
	} else if (surface_style == 3) {
		float fracture = 1.0 - smoothstep(0.011, 0.048, abs(detail - 0.5));
		albedo = mix(albedo, low * 0.65, fracture * 0.32);
	} else if (surface_style == 4 || surface_style == 6) {
		float crack = 1.0 - smoothstep(0.02, 0.13, abs(detail + (fine - 0.5) * 0.15 - 0.5));
		float molten = surface_style == 4 ? smoothstep(0.02, 0.23, light) : crack * smoothstep(0.48, 0.7, rock);
		albedo = mix(low * (0.7 + value * 0.55), high, molten * 0.84);
		emission = high * molten * (0.23 + crack * 0.34);
	} else if (surface_style == 5) {
		albedo = mix(low, high * 0.68, value);
		albedo = mix(albedo, atmosphere_color.rgb, smoothstep(0.45, 0.75, vapor + detail * 0.12) * 0.72);
	}
	vec3 world = albedo * mix(vec3(0.14, 0.19, 0.27), vec3(1.02, 0.99, 0.94), day)
		+ emission + atmosphere_color.rgb * rim * atmosphere_strength * 0.45;
	float halo = (1.0 - smoothstep(1.0, min(disc_extent, 1.18), r)) * rim * atmosphere_strength * 0.66;
	vec4 body = vec4(world * disc + atmosphere_color.rgb * halo * (1.0 - disc), disc + halo * (1.0 - disc));
	if (rings) {
		vec2 q = rotate_point(point, axis_angle);
		float ring_radius = length(vec2(q.x, q.y / ring_tilt));
		float edge = max(fwidth(ring_radius), 0.004);
		float ring = smoothstep(1.19 - edge, 1.19 + edge, ring_radius) * (1.0 - smoothstep(1.77 - edge, 1.77 + edge, ring_radius));
		ring *= (0.64 + sin(ring_radius * 143.0) * 0.15 + sin(ring_radius * 75.0) * 0.14) * smoothstep(0.013, 0.036, abs(ring_radius - 1.50));
		float shadow = mix(0.27, 0.92, smoothstep(-1.1, -0.55, dot(point, sunward)));
		vec4 dust = vec4(mix(low, high, 0.78) * ring * shadow, ring);
		body = q.y > 0.0 ? dust + body * (1.0 - dust.a) : body + dust * (1.0 - body.a);
	}
	return body;
}

void fragment() {
	vec2 point = (UV * 2.0 - 1.0) * disc_extent;
	float distance_to_center = length(point);
	float edge_width = max(fwidth(distance_to_center), 0.0001);
	float disc = 1.0 - smoothstep(1.0 - edge_width, 1.0 + edge_width, distance_to_center);
	if (stellar_style >= 0) {
		COLOR = star_model(point, distance_to_center, disc);
	} else if (surface_style >= 0) {
		COLOR = planet_model(point, distance_to_center, disc);
	} else if (body_kind == 0 || body_kind == 3) {
		bool blue = body_kind == 3;
		vec3 radiance = vec3(0.0);
		if (disc < 1.0 && distance_to_center < disc_extent) {
			float altitude = max(distance_to_center - 1.0, 0.0);
			float angle = atan(point.y, point.x + 0.00001);
			vec2 rim = vec2(cos(angle), sin(angle));
			float flare = texture(surface_noise, rim * 0.7 + vec2(TIME * 0.0125, -TIME * 0.009)).r;
			float corona = exp(-altitude * 5.0) * (0.8 + flare);
			float outer_glow = exp(-altitude * 1.65) * (0.9 + flare * 0.5);
			float fade = 1.0 - smoothstep(disc_extent * 0.68, disc_extent, distance_to_center);
			vec3 corona_color = blue ? vec3(0.10, 0.37, 0.75) : vec3(0.56, 0.26, 0.072);
			vec3 halo_color = blue ? vec3(0.024, 0.13, 0.32) : vec3(0.34, 0.125, 0.032);
			radiance = (corona_color * corona + halo_color * outer_glow) * fade * (1.0 - disc);
		}
		if (disc > 0.0) {
			float depth = sqrt(max(1.0 - dot(point, point), 0.0));
			vec2 surface = point + depth * vec2(0.27, -0.19);
			float terrain = texture(surface_noise, surface * 0.37 + vec2(0.42, 0.18) + vec2(TIME * 0.01, -TIME * 0.004)).r;
			float detail = texture(surface_noise, surface * 1.81 + vec2(0.14, 0.61) + vec2(-TIME * 0.0175, TIME * 0.01)).r;
			float plasma = smoothstep(0.22, 0.8, terrain * 0.42 + detail * 0.58);
			vec3 legacy_surface_dark = blue ? vec3(0.26, 0.64, 1.0) : vec3(1.0, 0.51, 0.16);
			vec3 legacy_surface_light = blue ? vec3(0.76, 0.93, 1.0) : vec3(1.0, 0.88, 0.56);
			vec3 photosphere = mix(legacy_surface_dark, legacy_surface_light, 0.38 + 0.32 * plasma + 0.25 * depth);
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
		vec3 legacy_atmosphere_color = vec3(0.28, 0.65, 1.0);
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
			legacy_atmosphere_color = vec3(1.0, 0.65, 0.38);
		} else if (body_kind == 5) {
			float ice = smoothstep(0.30, 0.70, terrain * 0.76 + detail * 0.24);
			albedo = mix(vec3(0.28, 0.31, 0.64), vec3(0.81, 0.86, 0.97), ice);
			legacy_atmosphere_color = vec3(0.42, 0.72, 1.0);
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
		COLOR = vec4(mix(legacy_atmosphere_color, lit_surface, disc) * opacity, opacity);
	} else {
		COLOR = vec4(0.0);
	}
}
