shader_type canvas_item;
render_mode unshaded;

uniform sampler2D relief_map : filter_linear, repeat_disable;
uniform vec2 relief_origin;
uniform vec2 relief_size = vec2(1.0);
uniform vec2 sun_direction = vec2(0.62, -0.78);

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
	vec3 sun = normalize(vec3(sun_direction, 0.82));
	float facing = dot(normal, sun) - sun.z;
	vec3 surface_light = vec3(1.0)
		+ max(facing, 0.0) * vec3(0.66, 0.58, 0.43)
		+ min(facing, 0.0) * vec3(0.68, 0.60, 0.47);

	// The second channel keeps the actual steps between surfaces for contact shadows.
	float height = texture(relief_map, relief_uv).g;
	float obstruction = 0.0;
	for (int i = 1; i <= 5; i++) {
		float distance_to_sample = float(i);
		float sunward_height = texture(relief_map, relief_uv + sun_direction * texel * distance_to_sample).g;
		obstruction = max(obstruction, sunward_height - height - 0.060 * distance_to_sample);
	}
	float shade = smoothstep(0.015, 0.24, obstruction);
	float depth = dot(relief_uv - 0.5, -sun_direction);
	float fill = 1.025 - 0.075 * smoothstep(0.03, 0.39, depth);
	COLOR.rgb *= surface_light * mix(vec3(1.0), vec3(0.58, 0.65, 0.78), shade) * fill;
}
