class_name MissionData
extends Resource
## A mission's setup: map and starting units. Roster entry i spawns on the
## team's spawn cell i (spawn cells are read row by row from the map).

@export var display_name: String = ""
@export var map: MapLayout
@export var blue_roster: Array[UnitStats] = []
@export var red_roster: Array[UnitStats] = []
## The human player's team; the other teams are AI (their heroes get recovered).
@export var player_team: SimUnit.Team = SimUnit.Team.BLUE
@export var hero_rules: HeroRules
## Capture-and-hold objective at the map's Orichalcum rock (null = none).
@export var objective: ObjectiveRules
## AI for every non-player team (null = no AI).
@export var ai_rules: AiRules
