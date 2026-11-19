extends Node

const THRUST_STREAM := preload("res://audio/engine-thrust.wav")
const OVERDRIVE_STREAM := preload("res://audio/engine-overdrive.wav")
const IGNITION_STREAM := preload("res://audio/engine-ignition.wav")
const SILENT_DB := -80.0
const SILENCE_THRESHOLD := 0.001

var volume := 0.7
var thrust_loop: AudioStreamPlayer
var overdrive_loop: AudioStreamPlayer
var ignition: AudioStreamPlayer

func _ready() -> void:
	thrust_loop = _make_player("ThrustLoop", THRUST_STREAM)
	overdrive_loop = _make_player("OverdriveLoop", OVERDRIVE_STREAM)
	ignition = _make_player("BoostIgnition", IGNITION_STREAM)

func update_mix(throttle: float, boost: float, hyper_jump: bool, delta: float) -> void:
	var overdrive := 1.0 if hyper_jump else boost
	var thrust_gain := volume * 0.48 * pow(throttle, 1.25) * lerpf(1.0, 0.72, overdrive)
	var overdrive_gain := volume * 0.43 * pow(overdrive, 0.8)
	_mix_loop(thrust_loop, thrust_gain, lerpf(0.90, 1.0, throttle) - 0.04 * overdrive, delta)
	_mix_loop(overdrive_loop, overdrive_gain, 0.94 if hyper_jump else lerpf(0.91, 1.0, boost), delta)

func play_boost(charge: float) -> void:
	if volume <= 0.0:
		return
	ignition.volume_db = linear_to_db(volume * lerpf(0.45, 0.7, charge))
	ignition.pitch_scale = lerpf(1.0, 0.89, charge)
	ignition.play()

func silence() -> void:
	for player in [thrust_loop, overdrive_loop, ignition]:
		player.stop()
		player.volume_db = SILENT_DB

func _make_player(player_name: String, stream: AudioStream) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.name = player_name
	player.stream = stream
	player.volume_db = SILENT_DB
	add_child(player)
	return player

func _mix_loop(player: AudioStreamPlayer, target_gain: float, target_pitch: float, delta: float) -> void:
	var gain := db_to_linear(player.volume_db)
	if not player.playing:
		if target_gain <= SILENCE_THRESHOLD:
			return
		player.pitch_scale = target_pitch
		player.play()
	gain = move_toward(gain, target_gain, (3.0 if target_gain > gain else 1.8) * delta)
	player.pitch_scale = move_toward(player.pitch_scale, target_pitch, delta * 1.5)
	player.volume_db = linear_to_db(gain) if gain > SILENCE_THRESHOLD else SILENT_DB
	if gain <= SILENCE_THRESHOLD and target_gain <= SILENCE_THRESHOLD:
		player.stop()
