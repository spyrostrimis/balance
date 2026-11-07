class_name MissionData
extends Resource
## A mission's setup: map and starting units. Roster entry i spawns on the
## team's spawn cell i (spawn cells are read row by row from the map).

@export var display_name: String = ""
@export var map: MapLayout
@export var blue_roster: Array[UnitStats] = []
@export var red_roster: Array[UnitStats] = []
