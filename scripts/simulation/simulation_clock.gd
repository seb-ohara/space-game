extends RefCounted
## One fixed simulation step per physics-server tick. Rate controls cadence, not step size.

const TICKS_PER_SECOND := 60
const STEP := 1.0 / TICKS_PER_SECOND
const RATES := [1, 2, 5, 10]
const SECONDS_PER_DAY := 86400
const DAYS_PER_YEAR := 365

var rate := 1
var paused := false
var elapsed: float:
	get: return _epoch_seconds + float(_ticks) / TICKS_PER_SECOND

var _epoch_seconds := 0.0
var _ticks := 0

func advance() -> void:
	_ticks += 1

func snapshot() -> Dictionary:
	return {"seconds": elapsed, "rate": rate, "paused": paused}

func restore(state: Dictionary) -> void:
	assert(valid_snapshot(state))
	_epoch_seconds = float(state.seconds)
	_ticks = 0
	rate = state.rate
	paused = state.paused

static func valid_snapshot(state: Variant) -> bool:
	if not state is Dictionary:
		return false
	var seconds: Variant = state.get("seconds")
	var speed: Variant = state.get("rate")
	return (seconds is float or seconds is int) and is_finite(seconds) and seconds >= 0 \
		and seconds <= 1.0e12 and speed is int and speed in RATES and state.get("paused") is bool

func calendar_text() -> String:
	var whole := floori(elapsed + 1e-8)
	@warning_ignore("integer_division")
	var days := whole / SECONDS_PER_DAY
	var day_seconds := whole % SECONDS_PER_DAY
	@warning_ignore("integer_division")
	return "Y%04d  ·  D%03d  ·  %02d:%02d:%02d" % [1 + days / DAYS_PER_YEAR, 1 + days % DAYS_PER_YEAR,
		day_seconds / 3600, (day_seconds % 3600) / 60, day_seconds % 60]
