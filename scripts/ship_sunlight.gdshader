shader_type canvas_item;

uniform sampler2D relief_map : filter_linear, repeat_disable;
uniform vec2 relief_origin;
uniform vec2 relief_size = vec2(1.0);
uniform vec2 hull_half_size = vec2(1.0);
uniform vec2 sun_direction = vec2(0.0);

varying vec2 relief_uv;

void vertex() {
	relief_uv = (VERTEX - relief_origin) / relief_size;
}

void fragment() {
	vec2 texel = 1.0 / vec2(textureSize(relief_map, 0));
	vec2 dx = vec2(texel.x, 0.0);
	vec2 dy = vec2(0.0, texel.y);
	vec2 slope = vec2(
		texture(relief_map, relief_uv + dx).r - texture(relief_map, relief_uv - dx).r,
		texture(relief_map, relief_uv + dy).r - texture(relief_map, relief_uv - dy).r);
	vec3 normal = normalize(vec3(-5.0 * slope, 1.0));
	float facing = dot(normal.xy, sun_direction);
	vec3 surface_light = vec3(1.0)
		+ max(facing, 0.0) * vec3(0.44, 0.38, 0.29)
		+ min(facing, 0.0) * vec3(0.38, 0.33, 0.25);

	// The second channel keeps the actual steps between surfaces for contact shadows.
	float height = texture(relief_map, relief_uv).g;
	float obstruction = 0.0;
	for (int i = 1; i <= 12; i++) {
		float distance_to_sample = float(i);
		float sunward_height = texture(relief_map, relief_uv + sun_direction * texel * distance_to_sample).g;
		obstruction = max(obstruction, sunward_height - height - 0.026 * distance_to_sample);
	}
	float shade = smoothstep(0.012, 0.24, obstruction);
	vec2 hull_position = relief_uv * relief_size + relief_origin;
	float depth = dot(hull_position, -sun_direction) / max(dot(hull_half_size, abs(sun_direction)), 1.0);
	float fill = 1.0 - 0.18 * smoothstep(0.0, 1.0, depth);
	COLOR.rgb *= surface_light * mix(vec3(1.0), vec3(0.48, 0.57, 0.72), shade) * fill;
}
