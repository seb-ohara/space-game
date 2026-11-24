# Drift living universe — Phase 1: universal simulation clock

Phase 1 is implemented. Phase 2 (persistent, node-independent entities) has not started. See the [Phase 0 audit](LIVING_UNIVERSE_PHASE_0.md) for the original baseline and plan.

## Player-facing changes

- The top-right flight toolbar shows the galactic date and a speed selector: **Paused, 1×, 2×, 5×, 10×**. A new galaxy starts at Year 1, Day 1, midnight; the calendar uses 365-day years and 24-hour days. One real second at 1× advances one simulated second. The original orbital-period and presentation multipliers are unchanged.
- Manual pause freezes gameplay but leaves camera and menus available. Settings and hangar temporarily stop simulation without overwriting the selected rate or clearing a manual pause. Time spent paused is not simulated on resume.
- Saves persist the galactic date, selected rate and manual pause state, separately from real session play time. Temporary menu pauses do not survive reload. Format 1 saves load with their existing elapsed time at 1×, unpaused; saving again writes format 2. Older builds that only read format 1 cannot open newly written format 2 files.
- When throughput drops below 90% of the selected speed for a sampling interval, the date line shows the achieved rate. The simulation slows down instead of taking larger physics steps or jumping ahead in time.

## Implementation decisions

- `scripts/simulation/simulation_clock.gd` is the sole owner of simulated time. `game.gd`'s `elapsed` is a read-only view used by orbits, combat and visual timestamps. The epoch plus integer tick count keeps fixed-step accumulation separate from wall time; `Time.get_ticks_usec()` is used for session time, camera/audio and the throughput readout.
- The driver uses **one fixed 1/60 simulated-second step per real Godot physics-server tick**. Instead of invoking multiple manual collision substeps inside one callback, the driver requests 60/120/300/600 physics ticks per real second. This preserves synchronization for the existing `CharacterBody2D` sweeps. `Engine.time_scale` stays at 1. The engine's per-frame step cap is the greater of the default or two times the rate (20 at 10×), and the driver restores project cadence when flight exits. There is no simulated catch-up after pause or jump in the clock for dropped wall-time steps. Existing bodies are moved by script; a future engine-integrated dynamic body would use Godot's real tick delta and would need explicit integration with the simulation clock.
- `game.gd` reuses the existing flight, fleet, boost, jump, mining and combat routines in `_step_flight`. World rebase also shifts parked RTS destinations and parked collision bodies so motion stays aligned with their ships. Presentation is queued during physics and submitted once per render frame: orbits are evaluated analytically at the latest clock value, and camera smoothing and engine audio use real cadence. Some effects still sample simulated steps so their trails or lifetimes track movement.
- `simulation_scheduler.gd` dispatches repeating jobs against simulation time. The first job invalidates the calendar once per simulated second; the HUD is updated during presentation. Physics, mining and shield updates still use precise steps rather than scheduled batches.
- `galaxy_saves.gd` validates v2 clock snapshots and migrates v1 `elapsed` and the `play_time` fallback independently of generator version, coordinates or fleet data. The change intentionally does not add persistence for temporary effects or for previously unsaved ship/order fields.

## Verification and performance

All nine headless regression scripts passed. `simulation_clock_test.gd` covers calendar rollover, cadence, single-dispatch scheduling, validation and snapshot restore. `simulation_flight_test.gd` exercises real engine physics callbacks at all four rates and compares the same simulated intervals: ore extraction/conservation, shield recharge, orbital positions, normal flight into a parked ship, sustained boost and a rebased hyperjump arrival. Collision positions and velocities are compared within a small float tolerance. It also checks pause through settings and hangar, and temporary settings pause at an active rate. `flight_persistence_test.gd` covers parked RTS rebasing, v1 migration, a malformed v2 clock, and saving and resuming a manually paused mid-jump at a saved rate of 5×. The two previously observed test shutdown leak diagnostics remain unrelated to this phase.

Apple M4, Godot 4.7.2, seed 7419. Headless callback timings below are medians over three runs; one RTS-moving starter ship. Flight initialization includes the first synchronous presentation refresh. The measured tick excludes presentation; the last column is the synchronous redraw setup, not GPU time. Original Phase 0 timings remain in the linked audit (the original script is in checkpoint `0459209`).

| Systems | Map (ms) | Form all (ms) | Flight init (ms) | Flight tick (ms) | Presentation (ms) |
|---:|---:|---:|---:|---:|---:|
| 100 | 0.635 | 41.636 | 48.910 | 0.697 | 0.383 |
| 250 | 1.577 | 105.077 | 49.010 | 0.699 | 0.398 |
| 500 | 3.014 | 223.004 | 50.898 | 0.736 | 0.521 |
| 1,000 | 6.392 | 427.406 | 52.172 | 0.730 | 0.561 |

Native 1280×720 window, Apple M4, OpenGL compatibility renderer, 1,000 systems, one RTS-moving ship, 60 FPS cap. Latest sample after warm-up:

| Requested rate | Achieved rate | FPS |
|---:|---:|---:|
| 1× | 1.002× | 60.1 |
| 2× | 2.000× | 60.0 |
| 5× | 4.998× | 60.1 |
| 10× | 10.003× | 51.6 |

A second run forced a 15 FPS cap and requested 10×: it achieved 4.998× at 15 FPS and showed the slowdown in the date line. These results demonstrate the prototype with one active ship on this hardware, not 10× throughput on all hardware, a populated galaxy, or a sustained 60 FPS guarantee. Asteroid field creation on a system crossing is still synchronous; the flight test exercises a crossing and arrival for correctness, not its worst-case latency. Existing off-screen state and save limitations remain Phase 2+ work.

```sh
godot --headless --path . --editor --import
for test in tests/*_test.gd; do
  godot --headless --path . --fixed-fps 60 --quit-after 2400 --script "res://$test"
done
godot --headless --path . --fixed-fps 60 --quit-after 600 --script res://tests/galaxy_baseline_benchmark.gd
godot --windowed --resolution 1280x720 --path . --script res://tests/simulation_realtime_benchmark.gd
godot --windowed --resolution 1280x720 --path . --script res://tests/simulation_realtime_benchmark.gd -- --overload
```

Changed `scripts/game.gd`, `scripts/game_input.gd`, `scripts/galaxy_saves.gd`, `tests/flight_persistence_test.gd` and `tests/galaxy_baseline_benchmark.gd`. Added the two simulation scripts and the clock/flight tests and rendered benchmark plus their Godot UID files. Updated `GAME_CONTEXT.md` and cross-linked the Phase 0 audit.
