extends RefCounted
## Transitional controller: operates on the game node, which still owns shared state.

const DAMAGE := preload("res://scripts/combat_damage.gd")

var game

func _init(owner) -> void:
	game = owner

func _update_combat(delta: float) -> void:
	game.invulnerability = maxf(0.0, game.invulnerability - delta)
	var recharge_time = maxf(0.0, delta - game.player_shield_delay)
	game.player_shield_delay = maxf(0.0, game.player_shield_delay - delta)
	if recharge_time > 0.0:
		var ship = game._custom_stats()
		game.player_shield = minf(ship.shield, game.player_shield + ship.shield_recharge * recharge_time)
	for i in range(game.shield_impacts.size() - 1, -1, -1):
		game.shield_impacts[i].life -= delta
		if game.shield_impacts[i].life <= 0.0:
			game.shield_impacts.remove_at(i)
	for i in range(game.hull_impacts.size() - 1, -1, -1):
		game.hull_impacts[i].life -= delta
		if game.hull_impacts[i].life <= 0.0:
			game.hull_impacts.remove_at(i)
	game.player_fire_cooldown = maxf(0.0, game.player_fire_cooldown - delta)
	game.machine_gun_cooldown = maxf(0.0, game.machine_gun_cooldown - delta)
	game.rocket_cooldown = maxf(0.0, game.rocket_cooldown - delta)
	game.railgun_cooldown = maxf(0.0, game.railgun_cooldown - delta)
	game._expire_rocket_effects()
	var living = 0
	var player_half_size = game._ship_size() * 0.5
	var player_rotation = game.heading + PI / 2.0
	for enemy in game.enemies:
		if not enemy.alive:
			continue
		living += 1
		enemy.shield_delay = maxf(0.0, enemy.shield_delay - delta)
		if enemy.shield_delay <= 0.0:
			enemy.shield = minf(enemy.max_shield, enemy.shield + enemy.max_shield * 0.1 * delta)
		if not enemy.hostile:
			game._update_neutral_ship(enemy, delta)
			continue
		var to_player: Vector2 = game.ship_position - enemy.position
		var distance = to_player.length()
		var away = -to_player / distance if distance > 0.01 else -Vector2.from_angle(enemy.heading)
		# Leave room for large custom hulls along the fighter's approach.
		var hull_clearance = player_half_size.dot(away.rotated(-player_rotation).abs()) + game._enemy_hull_radius(enemy, away) + 100.0
		var extra_range = maxf(0.0, hull_clearance - game.ENEMY_MIN_COMBAT_RANGE)
		var aim = to_player
		if distance > 0.01:
			aim = to_player + game.velocity * minf(distance / 800.0, 1.0) * 0.65
			enemy.aim_angle = aim.angle()
			game._steer_other_ship(enemy, aim, delta)
		var desired_velocity = game._enemy_combat_velocity(enemy, away, distance, extra_range)
		var current_velocity: Vector2 = enemy.velocity
		enemy.velocity = current_velocity.move_toward(desired_velocity, game.ENEMY_ACCELERATION * delta)
		enemy.position += enemy.velocity * delta
		enemy.fire_cooldown -= delta
		var in_firing_range = distance >= game.ENEMY_MIN_COMBAT_RANGE + extra_range and distance <= game.ENEMY_FIRE_RANGE + extra_range
		if in_firing_range and enemy.fire_cooldown <= 0.0 and absf(angle_difference(enemy.heading, aim.angle())) < 0.25:
			game._fire_enemy_turret(enemy)
	var aim_position = game._aim_world_position()
	if game.firing and game.selected_weapon == 1 and game.player_fire_cooldown <= 0.0:
		var fired = false
		for part in game.cached_turret_mounts:
			if part.get("turret", "") == "laser" and game._turret_is_aimed(part, aim_position):
				var origin = game._turret_world_position(part)
				var direction = Vector2.from_angle(game._turret_angle(part))
				game.projectiles.append({"position": origin, "velocity": direction * 800.0, "friendly": true, "damage": game.MODULES.TYPES[part.turret].weapon})
				fired = true
		if fired:
			game.player_fire_cooldown = 0.4
	if game.firing and game.selected_weapon == 3 and game.machine_gun_cooldown <= 0.0:
		var fired = false
		var heritage_fired = false
		for part in game.cached_turret_mounts:
			if part.turret in game.WEAPON_SLOTS[2].turrets and game._turret_is_aimed(part, aim_position):
				var key = game._turret_key(part)
				var burst = game._next_machine_gun_shot(game.player_machine_gun_shots.get(key, {}))
				game.player_machine_gun_shots[key] = burst
				var angle = game._turret_angle(part)
				var origin = game._turret_world_position(part)
				if part.turret == game.MODULES.CRUISER_MACHINE_LASER:
					var muzzle = origin + game.MODULES.cruiser_laser_muzzle_offset(part, burst.barrel, angle + PI / 2.0, game._cruiser_barrel_recoil(burst))
					game.projectiles.append({
						"position": muzzle, "muzzle": muzzle, "velocity": Vector2.from_angle(angle) * game.CRUISER_LASER_SPEED,
						"friendly": true, "damage": game.CRUISER_LASER_DAMAGE, "kind": game.MODULES.CRUISER_MACHINE_LASER,
					})
				else:
					var muzzle = origin
					var direction = Vector2.from_angle(angle).rotated(game.rng.randf_range(-0.035, 0.035))
					game.projectiles.append({"position": muzzle, "velocity": direction * 1200.0 + game.velocity * 0.25, "friendly": true, "damage": 4.0, "kind": "bullet"})
				fired = true
				heritage_fired = heritage_fired or part.turret == "retro_machine_gun"
		if fired:
			game.machine_gun_cooldown = 0.10
		if heritage_fired:
			game.heritage_gun_audio.pitch_scale = randf_range(0.96, 1.04)
			game.heritage_gun_audio.play()
	if game.firing and game.selected_weapon == 4 and game.rocket_cooldown <= 0.0:
		var fired = false
		for part in game.cached_turret_mounts:
			if part.get("turret", "") == "missile" and game._turret_is_aimed(part, aim_position):
				var origin = game._turret_world_position(part)
				var rocket = game._make_rocket(origin, game._turret_angle(part), game.velocity, true, game.MODULES.TYPES.missile.weapon, game.cached_ship_scale)
				rocket.position = origin
				game.projectiles.append(rocket)
				game.player_rocket_launches[game._turret_key(part)] = game.elapsed
				fired = true
		if fired:
			game.rocket_cooldown = game.ROCKET_COOLDOWN
	if game.firing and game.selected_weapon == 5 and game.railgun_cooldown <= 0.0:
		var fired = false
		for part in game.cached_turret_mounts:
			if part.get("turret", "") == "railgun" and game._turret_is_aimed(part, aim_position):
				var direction = Vector2.from_angle(game._turret_angle(part))
				var muzzle = game._turret_world_position(part)
				game.projectiles.append({"kind": "railgun", "position": muzzle, "velocity": direction * game.RAILGUN_SPEED,
					"friendly": true, "damage": game.MODULES.TYPES.railgun.weapon, "muzzle": muzzle})
				fired = true
		if fired:
			game.railgun_cooldown = game.RAILGUN_COOLDOWN
	for i in range(game.projectiles.size() - 1, -1, -1):
		var shot: Dictionary = game.projectiles[i]
		var is_rocket: bool = shot.get("kind", "") == "rocket"
		if is_rocket:
			game._update_rocket(shot, delta)
		var previous: Vector2 = shot.position
		var end: Vector2 = previous + shot.velocity * delta
		shot.position = end
		var asteroid_contact: Variant = game._asteroid_shot_contact(previous, end)
		var impact_point: Variant = asteroid_contact
		var closest = previous.distance_squared_to(asteroid_contact) if asteroid_contact != null else INF
		var hit = false
		if shot.friendly:
			var hit_index = -1
			var hit_point: Variant = null
			var segment_center = (previous + end) * 0.5
			var half_length = previous.distance_to(end) * 0.5
			for j in range(game.enemies.size()):
				var enemy: Dictionary = game.enemies[j]
				if not enemy.alive:
					continue
				var broad_radius = float(enemy.radius) + game.SHIELD_MARGIN
				var broad_distance = broad_radius + half_length
				if segment_center.distance_squared_to(enemy.position) > broad_distance * broad_distance:
					continue
				var contact: Variant = game._enemy_shot_contact(previous, end, enemy)
				if contact != null and previous.distance_squared_to(contact) < closest:
					closest = previous.distance_squared_to(contact)
					hit_index = j
					hit_point = contact
			if hit_index >= 0:
				impact_point = hit_point
				var enemy: Dictionary = game.enemies[hit_index]
				enemy.hostile = true
				var damage: float = shot.get("damage", 35.0)
				var result := DAMAGE.apply(enemy.shield, enemy.health, damage)
				if result.absorbed > 0.0:
					game._shield_hit(hit_index, hit_point, enemy.position, enemy.heading)
				else:
					game._hull_hit(hit_index, hit_point, enemy.position, enemy.heading)
				enemy.shield = result.shield
				enemy.shield_delay = 4.0
				enemy.health = result.hull
				hit = true
				if enemy.health <= 0:
					enemy.alive = false
					game._break_up_enemy(enemy)
					if game.selected_enemy == hit_index:
						game.selected_enemy = -1
						game.laser_active = false
						game.machine_gun_active = false
		elif game.invulnerability <= 0.0:
			var contact: Variant = game._player_shot_contact(previous, end)
			if contact != null and previous.distance_squared_to(contact) < closest:
				impact_point = contact
				var damage = float(shot.get("damage", 10.0))
				var result := DAMAGE.apply(game.player_shield, game.player_hull, damage)
				if result.absorbed > 0.0:
					game._shield_hit(-1, contact, game.ship_position, game.heading)
				else:
					game._hull_hit(-1, contact, game.ship_position, game.heading)
				game.player_shield = result.shield
				game.player_shield_delay = 4.0
				game.player_hull = result.hull
				hit = true
				if game.player_hull <= 0:
					if game.sustained_boost_enabled:
						game._set_sustained_boost(false)
					game._close_hyperjump_chart()
					game.hyperjump_time = -1.0
					game.hyperjump_arrival_until = 0.0
					game.player_hull = game._player_max_hull()
					game.player_shield = game._player_max_shield()
					game.player_shield_delay = 0.0
					game.shield_impacts.clear()
					game.hull_impacts.clear()
					game.ship_position = game.solar_system.starting_position()
					game.ship_motion_remainder = Vector2.ZERO
					game.velocity = Vector2.ZERO
					game._reset_player_exhaust()
					game.boost_decelerating = false
					game.selected_asteroid = -1
					game.selected_enemy = -1
					game.mining_asteroid = -1
					game.laser_active = false
					game.machine_gun_active = false
					game.player_machine_gun_shots.clear()
					game.player_rocket_launches.clear()
					game.mining = false
					game.invulnerability = 3.0
		if not hit and asteroid_contact != null:
			game._add_surface_impact(game.ASTEROID_IMPACT_INDEX, asteroid_contact, previous - end)
			hit = true
		if is_rocket:
			game._emit_rocket_smoke(shot, previous, impact_point if hit else end, delta)
			if hit:
				game.rocket_blasts.append({"position": impact_point, "born": game.elapsed})
		if hit or not game._world_bounds().has_point(end):
			game.projectiles.remove_at(i)
	if game.ENEMY_SHIPS_ENABLED and living == 0:
		if game.enemy_wave_timer < 0.0:
			game.enemy_wave_timer = 12.0
		else:
			game.enemy_wave_timer -= delta
			if game.enemy_wave_timer <= 0.0:
				game._spawn_enemy_wave()

