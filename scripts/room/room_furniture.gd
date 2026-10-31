@tool
extends Node3D
## One authored model and one picking volume per furniture item.
@export var bounds := Vector3.ONE
@export var blocking := true
@export var role := "chair"
