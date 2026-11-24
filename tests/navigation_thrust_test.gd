extends SceneTree

const GAME = preload("res://scripts/game.gd")

func _initialize() -> void:
	var game = GAME.new()
	var course := Vector2.RIGHT
	var stopped: Vector2 = game._navigation_velocity(Vector2.ZERO, Vector2.LEFT, course, 100.0, 20.0, 0.1)
	assert(stopped == Vector2.ZERO)
	var drifting: Vector2 = game._navigation_velocity(Vector2.LEFT * 10.0, Vector2.LEFT, course, 100.0, 20.0, 0.1)
	assert(drifting.x < 0.0 and drifting.length() < 10.0)
	var aligned: Vector2 = game._navigation_velocity(Vector2.ZERO, Vector2.RIGHT, course, 100.0, 20.0, 0.1)
	assert(aligned.is_equal_approx(Vector2.RIGHT * 2.0))
	var angled := Vector2.from_angle(0.1)
	var accelerated: Vector2 = game._navigation_velocity(Vector2.ZERO, angled, course, 100.0, 20.0, 0.1)
	assert(absf(accelerated.cross(angled)) < 0.0001)
	game.free()
	print("Navigation thrust checks passed")
	quit()
