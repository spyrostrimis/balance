class_name SimCommand
extends RefCounted
## Base class for orders. The view/AI creates commands; SimWorld applies them
## at the start of its next tick. Input never changes sim state directly.

## The team issuing the order. Commands only affect that team's units.
var team: SimUnit.Team = SimUnit.Team.BLUE


func apply(_world: SimWorld) -> void:
	pass
