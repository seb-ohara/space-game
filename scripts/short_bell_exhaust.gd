extends RefCounted

# Size.x is the nominal half-width, size.y is the length at full throttle without boost.
const TEXTURE_HALF_WIDTH := 1.25
const PRESET_LENGTH_FACTOR := 160.0
const MODULE_LENGTH_FACTOR := 65.0
const WIDTH_FACTOR := 9.4

static func base_size(nozzle_size: Vector2, preset: bool) -> Vector2:
	return nozzle_size * Vector2(WIDTH_FACTOR, PRESET_LENGTH_FACTOR if preset else MODULE_LENGTH_FACTOR)

static func dimensions(size: Vector2, power: float, boost: float) -> Vector2:
	return size * Vector2((0.58 + 0.42 * power) * (1.0 + 0.18 * boost), (0.24 + 0.76 * power) * (1.0 + 0.35 * boost))

static func flicker(time: float, phase: float) -> float:
	var angle := time * 17.0 + phase
	return 1.0 + 0.072 * (0.62 * sin(angle) + 0.38 * sin(angle * 1.83))

static func intensity(power: float) -> float:
	return smoothstep(0.0, 0.18, power) * (0.79 + 0.21 * power)

static func make_flame_image() -> Image:
	# Bake the approved transverse heat gradient and longitudinal taper once.
	# Scaling the shared texture gives each bell its own animation without per-nozzle shaders.
	var image := Image.create_empty(96, 256, false, Image.FORMAT_RGBA8)
	for y in range(image.get_height()):
		var u := float(y) / float(image.get_height() - 1)
		var width := (0.88 + 0.22 * sin(PI * minf(1.0, u * 2.4))) * pow(1.0 - u, 0.68)
		var central_heat := 1.0 - smoothstep(0.08, 0.73, u)
		var gold_falloff := 1.0 - 0.35 * smoothstep(0.45, 1.0, u)
		var tip := 1.0 - smoothstep(0.62, 1.0, u)
		for x in range(image.get_width()):
			var across := (2.0 * (float(x) + 0.5) / float(image.get_width()) - 1.0) * TEXTURE_HALF_WIDTH
			var r := absf(across) / maxf(0.001, width)
			var edge := 1.0 - smoothstep(0.56, 1.18, r)
			var core := (1.0 - smoothstep(0.10, 0.71, r)) * central_heat
			var gold := (1.0 - smoothstep(0.35, 1.05, r)) * gold_falloff
			var white := minf(1.0, core * 1.48)
			var alpha := minf(1.0, tip * (edge * (0.79 + 0.17 * gold) + 0.32 * core))
			image.set_pixel(x, y, Color(1.0, lerpf(71.0 + 105.0 * gold, 255.0, white) / 255.0,
				lerpf(13.0 + 49.0 * gold, 244.0, white) / 255.0, alpha))
	image.generate_mipmaps()
	return image
