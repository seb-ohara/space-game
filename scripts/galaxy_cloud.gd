extends ColorRect

const GALAXY := preload("res://scripts/galaxy_generator.gd")
const CLOUD := preload("res://scripts/galaxy_cloud.gdshader")

var atmosphere := ShaderMaterial.new()
var galaxy_scale := Vector2.ZERO
var galaxy_center := Vector2.ZERO
var configured := false

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	atmosphere.shader = CLOUD
	material = atmosphere
	hide()

func configure(data: Dictionary) -> void:
	configured = int(data.get("generator_version", 0)) in [GALAXY.CLOUD_VERSION, GALAXY.VERSION]
	if not configured:
		hide()
		return
	var shape: Dictionary = data.spiral
	galaxy_scale = shape.scale
	galaxy_center = (data.world_size as Vector2) * 0.5
	atmosphere.set_shader_parameter("lane_scale", minf(1.0, 3.6 / int(shape.arms)) if data.generator_version == GALAXY.VERSION else 1.0)
	for key in ["rotation", "phase", "winding", "arms"]:
		atmosphere.set_shader_parameter(key, shape[key])

func show_cloud(camera: Transform2D, opacity: float, growth := 1.16, origin_x := 0.0, origin_y := 0.0) -> void:
	visible = configured and opacity > 0.001
	if not visible:
		return
	size = galaxy_scale * (2.32 * camera.x.length())
	position = camera * Vector2(galaxy_center.x - origin_x, galaxy_center.y - origin_y) - size * 0.5
	atmosphere.set_shader_parameter("opacity", opacity)
	atmosphere.set_shader_parameter("growth", growth)
