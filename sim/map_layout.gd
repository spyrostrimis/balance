class_name MapLayout
extends Resource
## A map as rows of characters (data file, see data/maps/). Parsed by MapGrid.
##
## Legend:
##   .  ground (passable)
##   ^  cliff (impassable)
##   #  rock / boulder (impassable)
##   O  Orichalcum deposit rock (impassable)
##   B  Blue spawn cell (ground)
##   R  Red spawn cell (ground)
## Row 0 is the north edge; x grows east, y grows south.

@export var display_name: String = ""
@export var rows: PackedStringArray = PackedStringArray()
