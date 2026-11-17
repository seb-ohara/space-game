shader_type canvas_item;

uniform vec2 impact_uv = vec2(0.5);
uniform vec2 aspect = vec2(1.0);
uniform float progress = 0.0;

void fragment() {
	vec4 hull = texture(TEXTURE, UV);
	vec2 offset = (UV - impact_uv) * aspect;
	float distance_from_hit = length(offset);
	float spread = mix(0.12, 0.21, smoothstep(0.0, 1.0, progress));
	float glow = exp(-distance_from_hit * distance_from_hit / (spread * spread));
	float fade = smoothstep(0.0, 0.12, progress) * (1.0 - smoothstep(0.25, 1.0, progress));
	vec3 blue = mix(vec3(0.12, 0.48, 0.90), vec3(0.66, 0.93, 1.0), clamp(dot(hull.rgb, vec3(0.299, 0.587, 0.114)), 0.0, 1.0));
	COLOR = vec4(blue, hull.a * glow * fade * 0.72);
}
