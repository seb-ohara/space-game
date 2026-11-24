extends RefCounted
## Rocket creation and movement, independent of scene and projectile ownership.

const MODULES := preload("res://scripts/ship_modules.gd")
const EJECTION_SPEED := 220.0
const IGNITION_DELAY := 0.14
const ACCELERATION := 1800.0
const TOP_SPEED := 1350.0
const ENEMY_SPEED_FACTOR := 0.78
const TAIL_OFFSET := 9.0

static func create(origin: Vector2, angle: float, carrier_velocity: Vector2, friendly: bool, damage: float, scale_factor: float = 1.0) -> Dictionary:
	var forward := Vector2.from_angle(angle)
	var drift := carrier_velocity.limit_length(460.0) * 0.35
	return {
		"kind": "rocket", "friendly": friendly, "damage": damage,
		"position": origin + forward * (MODULES.ROCKET_MUZZLE_OFFSET * scale_factor + TAIL_OFFSET),
		"velocity": forward * EJECTION_SPEED + drift, "launch_drift": drift,
		"rocket_heading": angle, "rocket_speed": EJECTION_SPEED, "age": 0.0,
		"smoke_distance": 0.0,
	}

static func update(shot: Dictionary, target_position: Vector2, delta: float) -> void:
	shot.age += delta
	var powered_time := clampf(shot.age - IGNITION_DELAY, 0.0, delta)
	var rocket_heading: float = shot.rocket_heading
	if not shot.friendly and powered_time > 0.0:
		var to_target: Vector2 = target_position - shot.position
		if to_target.length_squared() > 1.0:
			var turn_limit := 1.6 * powered_time
			rocket_heading += clampf(angle_difference(rocket_heading, to_target.angle()), -turn_limit, turn_limit)
	shot.rocket_heading = rocket_heading
	var speed_factor := 1.0 if shot.friendly else ENEMY_SPEED_FACTOR
	shot.rocket_speed = move_toward(shot.rocket_speed, TOP_SPEED * speed_factor, ACCELERATION * speed_factor * powered_time)
	shot.velocity = Vector2.from_angle(rocket_heading) * shot.rocket_speed + shot.launch_drift * exp(-shot.age * 4.5)
