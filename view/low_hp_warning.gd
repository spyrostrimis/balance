class_name LowHpWarning
extends RefCounted
## Fires once when the watched hero's HP drops below the threshold, and again
## only after it has been healed back above it (design/GDD.md → Heroes).

var threshold: float = 0.3
## True while below the threshold (and still up): the portrait pulses.
var active: bool = false


func _init(fraction: float) -> void:
	threshold = fraction


## Call every frame. Returns true on the frame the warning fires.
func update(hp_fraction: float, is_up: bool) -> bool:
	var low: bool = is_up and hp_fraction < threshold
	var fired: bool = low and not active
	active = low
	return fired
