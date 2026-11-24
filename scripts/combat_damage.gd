extends RefCounted
## Shared shield/hull damage rules. The caller owns health, effects and death.

static func apply(shield: float, hull: float, damage: float) -> Dictionary:
	var absorbed := minf(shield, damage)
	return {
		"absorbed": absorbed,
		"shield": shield - absorbed,
		"hull": hull - (damage - absorbed),
	}
