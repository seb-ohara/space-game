# Drift — Phase 4: autonomous ship orders

## Player controls

1. Open **Fleet**, select an owned ship and choose **Move, Hyperjump, Mine, Stop, Wait or Idle**. **Replace orders** cancels that ship's existing queue; **Queue order** appends. **Cancel all orders** clears the queue and brakes the ship.
2. For Move and Mine, click a location or visible asteroid after the Fleet window hides. Escape cancels target picking. Hyperjump takes a system chosen in the panel and uses physical travel. Wait takes simulated seconds. One-time Mine takes an iron quantity. Repeat Mine keeps working the selected rock until its cargo hold is full or the deposit is depleted; Repeat Wait holds the queue until cancelled.
3. RTS right-click assigns moves to the selected ships (preserving formation offsets); Shift + right-click appends. With the mining weapon selected, right-clicking an asteroid issues a repeat Mine. Fleet shows each active order stage and pending count. Assignment/outcome notices appear in the flight HUD, and the last outcome is available on the fleet row.
4. Direct flight input temporarily suspends an order on the controlled ship until controls are released. An in-progress hyperjump is not suspended by normal thrust input; use an explicit Stop or cancel in Fleet. Switching ships does not cancel assignments.

## Implementation and compatibility

- `scripts/ships/ship_order.gd`, `ship_order_queue.gd` and `ship_order_controller.gd` define serializable instructions, the per-ship FIFO/terminal status and execution state machine. The controller reuses current movement, approach, braking, jump and extraction behavior; it does not choose economic work on its own. Orders have stable IDs, explicit repeat rules, arrival checks, split wait/mine progress, and result reasons for completion, inability, stalling, exhaustion or cancellation.
- `game.gd`, `game_input.gd` and `fleet_order_panel.gd` bridge controls, navigation projection, target lookup and notifications. Visual and off-screen miners reference the same deterministic asteroid ID and save-backed remaining ore. The same extraction calculation handles manual and assigned work; updated inventory and reserve quantities are applied sequentially in the simulation. Off-screen asteroid lookups cache only the requested deposit's data, not asteroid nodes or entire generated belts. `asteroid_factory.gd` exposes the original reserve formula and `flight_navigation.gd` exposes its arrival radius.
- Save format 4 persists per-ship order queues, last outcome, sequence counter, target positions, stages and partial progress (including fractional extraction). Saves from formats 1–3 still load. Old in-flight move/jump state is migrated to an equivalent explicit order when available; it keeps its original absolute target and jump progress. Older binaries cannot open format 4.

## Verification

All **12 headless regression scripts passed**. `tests/autonomous_orders_test.gd` verifies the Fleet asteroid picker, queueing, physical approach, off-screen extraction after a control handoff to another system, mid-extraction save/load, shared reserve conservation, one-time completion, repeat blocking, manual-input interruption and resumption, replacement/cancellation, and off-screen physical hyperjump progress and arrival at 1× and 10×. Existing movement/contact/orbit/mining parity remains covered at 1×, 2×, 5× and 10×. `tests/flight_persistence_test.gd` covers v1–v3 migration. The two existing Godot shutdown leak diagnostics are unchanged.

M4, Godot 4.7.2, 1,000-system headless baseline: **0.731 ms** per gameplay tick with the pilot only; **1.369 ms** with 100 additional off-screen Move orders. Synchronous presentation took **0.516 ms** and **0.550 ms**, respectively. This is CPU callback timing, not a rendered frame-rate guarantee or a benchmark for 100 simultaneous asteroid lookups. The `--fleet` variant also completed at 100, 250 and 500 systems.

```sh
godot --headless --path . --fixed-fps 60 --quit-after 2400 --script res://tests/autonomous_orders_test.gd
godot --headless --path . --fixed-fps 60 --quit-after 600 --script res://tests/galaxy_baseline_benchmark.gd -- --fleet
```

## Current limits

Mines target one existing iron asteroid. A continuous order does not select new rocks, unload its hold, travel to a station or sell goods. To dispatch a ship from another star system, queue Hyperjump before local work. Distant ships do not run detailed physics contacts; the order controller can fail a stalled leg but does not route around obstacles. Generic resources, resource-aware asteroid fields, stations and trade remain later phases. Phase 5 has not started.
