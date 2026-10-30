@tool
extends Button
## Authored Polygon2D / ColorRect nodes; no runtime geometry construction.
@export_enum("computer", "desk", "peripheral", "cabinet", "decor") var kind := "computer"
@export var art_size := Vector2(100, 100)
var upgraded := false
var trophy_count := 0
var microphone := false
var original_colors: Dictionary = {}

func _ready() -> void:
	_remember_colors(self)
	resized.connect(_fit_art)
	_fit_art()

func _remember_colors(parent: Node) -> void:
	for child in parent.get_children():
		if (child is ColorRect or child is Polygon2D) and child.has_meta("upgraded_color"):
			original_colors[child] = child.color
		_remember_colors(child)

func _fit_art() -> void:
	if has_node("Art") and art_size.x > 0 and art_size.y > 0:
		$Art.scale = size / art_size

func refresh_appearance() -> void:
	for child in original_colors:
		child.color = child.get_meta("upgraded_color") if upgraded else original_colors[child]
	var microphone_node := get_node_or_null("Art/Microphone")
	if microphone_node != null: microphone_node.visible = microphone
	for index in range(3):
		var trophy := get_node_or_null("Art/Trophy%d" % index)
		if trophy != null: trophy.visible = index < trophy_count
