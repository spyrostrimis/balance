class_name ObjectiveRules
extends Resource
## Capture-and-hold objective numbers (design/GDD.md → Mission 1).

## The zone: open cells within this many cells (Chebyshev) of the rock.
@export var zone_radius: int = 2
## Seconds a side must be alone in the zone to take the rock.
@export var capture_seconds: float = 10.0
## Seconds the owner must keep every enemy out of the zone to win.
@export var hold_seconds: float = 60.0
