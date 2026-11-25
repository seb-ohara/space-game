# Drift — game context and current implementation

*Codebase snapshot: 24 November 2026. This document describes what is present in the project, not a promise of planned features. Values are tuning constants and may change. It is intended to be copied into another AI conversation.*

## Overview

Drift is a top-down 2D space flight prototype made in Godot 4.7 using GDScript and the GL Compatibility renderer. The player creates or loads a seeded galaxy, flies ships around a continuous large-scale world, visits generated star systems, mines asteroids, manages ships and loadouts, and can use faster travel between systems. The project combines direct piloting with RTS-style selection and movement. It has procedural astronomy and combat foundations, but it should be treated as an evolving prototype rather than a finished space simulation.

The player starts in the Sol system near a deliberately placed terrestrial world and asteroid. The galaxy, its stars, systems and asteroid sites are reproducible from their seed and generator version. Ship flight and the presentation of celestial bodies are designed for playability rather than consistent physical scale.

## Project map

- `project.godot`, `main.tscn`: Godot project and entry scene. The principal game node is implemented in `scripts/game.gd`.
- `scripts/home_menu.gd`, `galaxy_preview.gd`, `galaxy_cloud.gd` and its shader: menus, galaxy creation and preview.
- `scripts/galaxy_generator.gd`: seeded galaxy, stellar properties, planetary formation and asteroid-site generation, including compatibility with older generation versions.
- `scripts/solar_system.gd`, `celestial_body.gdshader`: star/planet/moon presentation, orbital positions and zoom-dependent visualization.
- `scripts/game.gd`: game-state orchestration, flight, fleet, camera, scene ownership and much of the world rendering. It remains the owner of shared game state and scene nodes.
- `scripts/combat_controller.gd`: the combat update loop, still coupled to game-node state and helpers. `scripts/combat_damage.gd` supplies shared shield/hull damage rules without owning a ship. Targeting, AI and effects helpers remain in `game.gd`.
- `scripts/mining_controller.gd`: stateless asteroid targeting, mining range and extraction rules. It receives values and returns results; the game node currently owns the player ship's mining progress, cargo, asteroid state and save data.
- `scripts/game_input.gd`: input and unhandled-input event routing. The game node forwards the Godot callbacks, and order, camera and menu helpers remain there.
- `scripts/game_hud.gd`: HUD and resource-panel drawing using the game node's canvas and state. World and tactical overlays remain in `game.gd`.
- `scripts/flight_navigation.gd`: reusable, stateless navigation thrust, steering and simple move-order calculations. The game owns ship state, collision movement and order lifecycle; active-player RTS flight still has its own arrival behavior.
- `scripts/projectile_geometry.gd`: swept projectile intersections with ellipses, polygons, asteroid fields and ship hulls.
- `scripts/rocket_projectile.gd`: rocket creation and flight mechanics; the game owns projectile state, smoke and rendering.
- `scripts/asteroid_factory.gd`: deterministic asteroid shape and ore data; the game owns loading, mining and visuals.
- `scripts/ship_modules.gd`, `ship_loadout.gd`, `ship_admin.gd`, `hangar.gd`, `ship_design_library.gd`: ship definitions, statistics, validation, loadouts, administration and library.
- `scripts/galaxy_saves.gd`, `settings_menu.gd`, `key_bindings.gd`: persistence, settings and controls.
- `tests/`: focused scripts for asteroid belts, navigation, game systems and controllers, ship scaling and loadouts. Assets are in directories including `ship-sprites`, `component-art`, `engine-art`, and `audio`.

## Galaxy creation and stars

The new-game menu accepts a name, seed, 1–1,000 star systems (default 5, including Sol), and 3–6 spiral arms (default 4). A blank seed is randomized. Generation has a visual preview. Generator version 5 is current; versions 1–4 remain supported for existing saves and use earlier grid, spiral, cloud and wide-orbit variants.

Version 5 builds a flattened, rotating spiral cloud with a core, arm lanes, uneven concentrations and voids. A significant fraction of systems are placed in small associations around existing stars. A spatial grid and minimum spacing check reduce overlapping systems. Sol is system 0; the other positions and stellar properties are generated from named random streams derived from the seed. Older versions use different spacing and/or placement, so seed alone is not the whole identity: retain the generator version and arm count as well.

Each evolved star has a mass, age, temperature, physical radius, luminosity, metallicity, evolutionary stage, visual radius and color. Most non-Sol stars are red dwarfs; other categories include ordinary main-sequence stars, red/blue giants and supergiants, white dwarfs and neutron stars/pulsars. Luminosity follows a radius-and-temperature relationship; metallicity depends partly on galactic radius. Evolved stars can have a different formation luminosity from their present luminosity, allowing the original frost line to differ from present-day conditions. Neutron stars have radiation and pulsar properties in their generated data. These properties do not by themselves imply that every physical effect is a gameplay hazard.

## Planetary formation: simplified accretion

Current wide-orbit generations form systems with a seeded, rule-based accretion model. This is a procedural approximation, not a continuous N-body or hydrodynamic simulation.

1. A circumstellar disc extends from beyond the star to an outer radius. Its physical AU range, frost line, density, gas supply and carbon/oxygen ratio depend on the star and random stream. The frost line is approximately `2.7 × sqrt(formation luminosity)` AU. Metallicity affects solid material; pulsar fallback discs are sparse and gas-free, and most neutron stars form no planets.
2. The disc is divided into 42 radial bands containing rock and, outside the frost line, ice. Embryos form in some bands and compete for nearby material over seven growth passes. Their feeding reach increases with accumulated solids; the frost boundary limits cross-boundary feeding.
3. Embryos become rocky worlds, super-Earths, ice/ocean/carbon/lava worlds or pulsar planets according to mass, composition and conditions. Sufficiently massive icy cores can gather a shared gas reservoir and become Neptunian or gas-giant worlds. Generated worlds carry properties including mass, radius, composition, temperatures and orbital details.
4. A non-home system can produce an inward-migrating gas-rich planet. Depending on temperature and other rolls, it may become a hot Jupiter, ultra-hot Neptune or stripped chthonian core. Migration can scatter a rocky world onto a more eccentric orbit and leave a debris belt; it can also be associated with a captured moon.
5. Some residual material produces a dwarf planet and associated uncleared debris, or up to three residual belts. Planets and moons are subject to clearance checks so their orbital extents do not overlap unacceptably. Gas worlds can receive multiple moons; rocky worlds can receive one, with cratered, icy, volcanic or mineral variants.

Sol has authored anchors inside the procedural system: a one-Earth-mass terrestrial starter planet with a moon, plus a Jupiter-like giant. Other content can still be generated around these. The generator stores formation history and origin data for relevant events. Planetary period in days is estimated with a Kepler-style formula, `365.25 × AU^1.5 / sqrt(stellar mass)`; equilibrium temperature uses approximately `278 × (luminosity / AU²)^0.25` K. These are metadata and classification aids, not a guarantee that the visual orbit uses real-time physical periods.

## Scale, orbital motion and rendering

The game's world is continuous and very large, but its units combine several different conventions. A nominal AU constant is 150,000 world units; disc distances are nonlinearly compressed using a power of 2.6, and current wide versions multiply generated orbital distances by four. Stars and planets have separately tuned visual radii. Do not infer real astronomical distances or proportions directly from the screen or from the HUD speed.

The solar-system renderer updates planets and moons along elliptical orbits using eccentric anomaly and a game clock. Planet and moon visual orbit speeds use separate scale factors (0.025 and 0.075 respectively). Orbits, body markers, star names and other details change with zoom; system contents are displayed selectively to keep large views usable. The galaxy uses a cloud visualization and distant map rendering, while close-up celestial surfaces use shaders. Lighting on ships is influenced by the nearest star.

A floating origin rebases local positions when the ship gets roughly 750,000 world units from the local origin. This avoids visible precision problems at galaxy scale. The game also retains a movement remainder and special arrival tolerance to mitigate rounding. Future systems that store world-space positions should account for rebasing and saved origin, rather than assuming local coordinates never change.

## Flight and speed

The base direct-flight tuning in `game.gd` is 390 world units/s top speed, 380 world units/s² acceleration, 0.32 drag and 3.1 radians/s base turning before ship-specific factors. Ship thrust-to-mass changes speed and acceleration; mass, length and steering affect turning. At ordinary flight speeds turning is progressively reduced, reaching 45% of the relevant turn rate at the speed limit. Angular velocity ramps rather than instantly snapping.

Manual forward thrust acts along the ship's heading and preserves existing sideways drift when the ship turns. Braking moves velocity toward zero at 1.25 times ship acceleration. Releasing thrust applies exponential drag, so this is arcade-style inertial flight, not frictionless Newtonian spaceflight. Speed above normal limits is gradually brought down after special travel.

The HUD deliberately scales speed: it converts world units to meters using 11.25 world units per meter and then multiplies by 100 for the displayed value. For example, a base 390 world units/s reads about 3.47 km/s before ship factors. Ship administration exposes speed-related values in displayed units; displayed speeds and physical world movement must not be treated as a single literal astronomical scale.

There are three faster-travel behaviors:

- **Charged burst:** In manual mode, hold Space for up to 2.5 seconds and release. The burst lasts approximately 0.85–2 seconds depending on charge, with stronger forward acceleration and a temporary limit of 1.75–3 times normal speed. Turning is reduced during the burst.
- **Sustained boost:** Toggle through the middle-click radial menu; pick a direction or destination by clicking. The base travel speed is 6,141.25 world units/s multiplied by the ship's speed factor unless overridden in ship administration. Acceleration and deceleration are managed separately, with navigation braking for arrival. Combat controls are cleared while using it.
- **Hyperjump:** Right-click a system on the map and select the available jump action. The ship physically travels toward an arrival point outside the destination system, steering, accelerating and braking; it is not simply teleported. Its default cruise speed derives from 25,500 world units/s times the ship speed factor and can be overridden. Nominal acceleration time is eight seconds. A flight-capable ship with positive speed is required; the current check does not consume a fuel resource.

Navigation brakes drift when the ship is substantially misaligned, then accelerates along its forward axis once aligned. RTS movement also slows for arrival, rather than allowing sideways main-engine acceleration. Exact behavior, including collision handling and world boundaries, is in `game.gd`.

## Controls, camera and fleet

Default bindings are configurable. In direct-flight mode W accelerates, S brakes, A/D turn, Space charges a burst, X fires, Tab cycles targets, 1–5 select weapon groups and F recenters the camera. In RTS mode the same directional keys pan the camera and Space recenters it. Mouse wheel zooms, Shift + left drag pans, left click/drag selects, right click issues contextual orders or selects a system, and middle click opens the radial menu. Selection and context can change what a click does.

The fleet UI can spawn ships from available designs, park and switch control between owned ships, and select/order ships using RTS controls. Ships have positions, heading, hull, shields and their own design/admin values. The active ship and other owned ships have collision handling; other fleet ships can move toward orders. Fleet and active-ship state are persisted. This is an early fleet-control implementation, not evidence of a complete strategy or autonomous fleet AI game.

## Ships, modules and hangar

The hangar provides built-in and saved ship designs, deployment and ship administration. Presets include an armoured starter, scout, light cruiser, gunship, cargo ship and small fighter. Designs use component dictionaries and can also include pixel-based preset hulls. The module system supports hull and structure, engines and thrusters, turret mounts, weapons, power cells, shields, cargo, command/bridge parts and decorative elements. It contains grid/layer, connectivity, overlap, mount and other validation rules, with a 400-component maximum. The presence of underlying component and validation code does not necessarily mean every conceivable construction workflow is exposed in the current hangar UI.

Module stats add mass, health, power, thrust, weapon, cargo and mining contributions. Thrust/mass determines speed and acceleration factors with caps; maneuverability incorporates mass and hull length. Adjacent same-type reactors or shields provide power bonuses. Shield generators have diminishing stacked capacity: the first contributes 60 and further contributions follow a 0.6 geometric factor; recharge depends on available positive power. Admin settings can override health, shield, cargo, speed, acceleration, turning, boost and hyperdrive values, and can change visual ship length. Preset dimensions and scale are separate from astronomical scaling.

The active loadout has up to 32 configurable slots, four by default, with positions expressed as fractions of the hull bounds. Slot types include lasers, machine guns, rockets, railguns, mining lasers, shield capacity (+100) and shield recharge (+2/s). Legacy visible turret mounts remain in saved designs for compatibility; the active player stat path removes their turret contribution in favor of the current slot-based approach. Consult the code when changing a ship's equipment so old and current systems are not accidentally counted twice.

## Mining, resources and asteroid fields

Belts are generated from leftover formation material or other formation events. Rather than filling an entire mathematical ring with rocks, the current system creates irregular local orbital arcs with dense and sparse patches, typically targeting 250–1,000 rock sites per belt, subject to placement checks. Rock spacing uses a 500-unit minimum check. Sol also has a guaranteed starter asteroid near the starting ship. Sites are deterministic, and stable IDs allow remaining ore to be associated with the same asteroid after loading.

Aim the selected mining laser at an asteroid within range and fire. A suitably aimed mining turret contributes mining rate, accumulating progress into iron units. Mining stops when the rock is exhausted or cargo is full. Iron and tritium share cargo capacity. Tritium drops and pickup logic exist for destroyed enemies, but the default enemy-spawning switch is disabled, so ordinary access to this resource should not be assumed. There is no basis in the inspected code to describe a finished crafting, economy or fuel-consumption loop.

## Combat and damage

Weapon groups are laser, mining laser, machine gun, rocket and railgun. Turrets turn toward targets and must be sufficiently aimed for the relevant firing/mining behavior. Projectiles and rockets have individual travel and collision logic; rockets have ejection, ignition delay, acceleration, smoke and impact effects. Hits interact with shields and hull, with shield impact visuals and a four-second recharge delay after a hit. The project also contains enemy targeting, steering, combat, death/debris and tritium-drop logic.

**Current limitation:** `ENEMY_SHIPS_ENABLED` is `false` in `game.gd`, so enemy waves are not enabled by default. Combat code should be described as implemented infrastructure rather than an active, fully populated enemy gameplay loop. Visual effects include exhaust, engine lighting and sound, weapon flashes, shield glow and impacts.

## Simulation clock

The in-flight top-right toolbar shows a galactic date and Paused/1×/2×/5×/10× controls. The authoritative simulation clock advances in 1/60 simulated-second ticks. Accelerated rates change Godot's physics tick cadence, not `Engine.time_scale` or the size of a gameplay step. Orbits, movement, mining and combat read simulation time; camera, presentation and session play time run separately. Settings and hangar pause simulation temporarily without changing the selected speed or manual pause state. If the engine cannot sustain the selected rate within its step budget, the calendar reports the achieved rate.

## Saves and settings

Galaxy saves use Godot's `user://galaxies` directory, one `.save` file per slot, with a temporary-file write and rename. The save includes name, seed, system count, generator version and arm count where applicable; fleet designs and positions, active ship, hull/shield data and administration; active velocity; iron and tritium; simulation time, speed, manual pause and real session play time; depleted ore; floating world origin; and an in-progress hyperjump if applicable. Galaxy layout and contents are regenerated deterministically from the saved generation parameters rather than relying on a fully serialized universe. The save reader validates format, version and key parameters. It opens format 1 saves at 1× unpaused with their prior elapsed time. Format 1 and 2 fleets migrate to per-ship state on load and the next save writes format 3. Recent and load/delete UI is provided. Saves happen at creation, through settings, on relevant admin changes and on window close. Do not assume that transient projectiles, enemies, every fleet movement order or all visual effects survive a reload.

Settings include control mode, key bindings and graphics/display options such as graphics quality, frame cap and VSync. They are stored separately from galaxy saves.

## Living-universe roadmap status

Phase 0 ([architecture audit and baseline](LIVING_UNIVERSE_PHASE_0.md)) and Phase 1 ([simulation clock and verification](LIVING_UNIVERSE_PHASE_1.md)) are complete. Regression coverage includes time-speed parity, ship contacts, rebasing, and legacy and current saves during hyperjump. The measured 1,000-system, one-ship prototype sustained 10× on Apple M4; this does not establish throughput for a populated galaxy or other hardware. [Phase 2](LIVING_UNIVERSE_PHASE_2.md) adds stable ownership and ship IDs, double-precision persistent ship positions, per-ship cargo, and off-screen movement independent of fleet visuals. The pilot can take control of another owned ship while the first continues its movement. Distant ships do not yet use detailed local hull contacts. Phase 3 has not started.

## Guidance for future development

- Treat this document as a snapshot; check the actual source before changing a formula or assuming a feature is exposed in the UI.
- Preserve seed, random stream, generator-version and stable asteroid-ID compatibility when changing procedural generation or loading old games.
- Keep local versus galaxy coordinates and floating-origin rebasing explicit. Account for the intentionally different world-distance, ship-size and HUD-speed scales.
- Distinguish direct flight, charged burst, sustained boost and hyperjump; they have different acceleration and control rules.
- Ship statistics, admin overrides, legacy mounts and slot loadouts interact. Check the whole calculation path before rebalancing.
- Separate procedural metadata and visuals from implemented gameplay effects; e.g. generated radiation is not automatically a radiation-damage system, and combat code is not the same as enabled enemy spawning.
