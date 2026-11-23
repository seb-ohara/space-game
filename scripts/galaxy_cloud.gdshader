shader_type canvas_item;
render_mode unshaded, blend_premul_alpha;

uniform float rotation;
uniform float phase;
uniform float winding;
uniform int arms = 2;
uniform float lane_scale = 1.0;
uniform float opacity = 1.0;
uniform float growth = 1.0;

float hash_point(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float cloud_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = smoothstep(vec2(0.0), vec2(1.0), fract(p));
	return mix(mix(hash_point(i), hash_point(i + vec2(1.0, 0.0)), f.x),
		mix(hash_point(i + vec2(0.0, 1.0)), hash_point(i + 1.0), f.x), f.y);
}

void fragment() {
	vec2 p = (UV * 2.0 - 1.0) * 1.16;
	float r = length(p);
	float theta = atan(p.y, p.x + 0.00001);
	float arm_distance = 3.14159;
	float dust_distance = 3.14159;
	float clumps = 0.0;
	// Same centerline as GalaxyGenerator.cloud_arm_angle().
	for (int i = 0; i < arms; i++) {
		float a = rotation + TAU * float(i) / float(arms) + winding * pow(r, 0.7)
			+ 0.085 * sin(r * 13.0 + phase + float(i) * 2.1);
		float d = mod(theta - a + PI, TAU) - PI;
		if (abs(d) < arm_distance) {
			arm_distance = abs(d);
			clumps = 0.5 + 0.5 * sin(r * 37.0 + phase + float(i) * 1.9);
		}
		dust_distance = min(dust_distance, abs(d - sign(winding) * 0.12 * lane_scale));
	}
	float n = cloud_noise(p * 17.0 + phase) * 0.62 + cloud_noise(p * 69.0 - phase) * 0.26
		+ cloud_noise(p * 180.0) * 0.12;
	float width = mix(0.28, 0.115, clamp(r, 0.0, 1.0)) * lane_scale;
	float arm = exp(-pow(arm_distance / width, 2.0) * 0.65);
	float disc = smoothstep(0.09, 0.29, r) * (1.0 - smoothstep(0.68, 1.10, r));
	float lane = exp(-pow((dust_distance + (n - 0.5) * 0.14) / 0.052, 2.0));
	float gas = arm * disc * mix(0.62, 1.3, clumps) * (0.17 + n * n) * (1.0 - 0.64 * lane);
	float knots = pow(max(0.0, n * clumps), 2.2) * arm * disc;
	float bulge = exp(-r * 10.8) * (0.84 + n * 0.38);
	float core = exp(-pow(r * 17.0, 1.5));
	vec3 light = vec3(0.16, 0.41, 0.76) * gas + vec3(0.62, 0.29, 0.52) * knots
		+ vec3(0.67, 0.36, 0.17) * bulge + vec3(0.27, 0.27, 0.22) * core;
	light *= opacity * (1.0 - smoothstep(growth - 0.15, growth + 0.15, r));
	COLOR = vec4(light, 0.0);
}
