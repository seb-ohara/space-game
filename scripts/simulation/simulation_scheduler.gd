extends RefCounted
## Repeating jobs on the simulation timeline, not wall time. Advance after each fixed step.

class Job:
	var interval: float
	var next_due: float
	var action: Callable

var _jobs: Array[Job] = []

func repeat(interval: float, elapsed: float, action: Callable) -> void:
	assert(interval > 0.0 and is_finite(interval))
	var job := Job.new()
	job.interval = interval
	job.next_due = (floor(elapsed / interval) + 1.0) * interval
	job.action = action
	_jobs.append(job)

func run_due(elapsed: float) -> void:
	for job in _jobs:
		if elapsed >= job.next_due:
			# Run once if a boundary was crossed, even on a discontinuous clock.
			job.next_due = (floor(elapsed / job.interval) + 1.0) * job.interval
			job.action.call()
