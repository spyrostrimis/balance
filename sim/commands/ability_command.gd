class_name AbilityCommand
extends SimCommand
## Use a hero's active ability on a unit: walk into range, then use it.

var unit_id: int = -1
var ability_index: int = -1
var target_id: int = -1


func _init(issuing_team: SimUnit.Team, caster: int, index: int, target: int) -> void:
	team = issuing_team
	unit_id = caster
	ability_index = index
	target_id = target


func apply(world: SimWorld) -> void:
	world.order_ability(team, unit_id, ability_index, target_id)
