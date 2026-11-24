extends SceneTree

const CLOCK := preload("res://scripts/simulation/simulation_clock.gd")
const SCHEDULER := preload("res://scripts/simulation/simulation_scheduler.gd")

func _initialize() -> void:
	var clock := CLOCK.new()
	assert(clock.elapsed == 0.0 and clock.calendar_text() == "Y0001  ·  D001  ·  00:00:00")
	clock.restore({"seconds": CLOCK.SECONDS_PER_DAY * CLOCK.DAYS_PER_YEAR - CLOCK.STEP,
		"rate": 5, "paused": true})
	assert(clock.calendar_text() == "Y0001  ·  D365  ·  23:59:59")
	var scheduled: Array[String] = []
	var scheduler := SCHEDULER.new()
	scheduler.repeat(1.0, clock.elapsed, func(): scheduled.append(clock.calendar_text()))
	# The driver does not advance the clock/dispatch jobs while paused.
	scheduler.run_due(clock.elapsed)
	assert(scheduled.is_empty())
	clock.paused = false
	clock.advance()
	scheduler.run_due(clock.elapsed)
	assert(scheduled == ["Y0002  ·  D001  ·  00:00:00"])
	scheduler.run_due(clock.elapsed)
	assert(scheduled.size() == 1)
	for tick in range(CLOCK.TICKS_PER_SECOND):
		clock.advance()
		scheduler.run_due(clock.elapsed)
	assert(scheduled.size() == 2 and scheduled[1].ends_with("00:00:01"))
	assert(not CLOCK.valid_snapshot({"seconds": NAN, "rate": 5, "paused": false}))
	assert(not CLOCK.valid_snapshot({"seconds": -1, "rate": 1, "paused": false}))
	assert(not CLOCK.valid_snapshot({"seconds": 0, "rate": 3, "paused": false}))
	assert(not CLOCK.valid_snapshot({"seconds": 0, "rate": 5, "paused": 0}))
	var restored := CLOCK.new()
	restored.restore(clock.snapshot())
	assert(restored.snapshot() == clock.snapshot())
	print("Simulation clock checks passed")
	quit()
