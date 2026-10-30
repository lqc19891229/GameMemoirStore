extends Button
## 外观由 furniture/*.tscn 的 ColorRect 节点组成，可替换为 TextureRect。
@export_enum("computer", "desk", "peripheral", "cabinet", "decor") var kind := "computer"
var upgraded := false
var trophy_count := 0
var microphone := false
var original_colors: Dictionary = {}

func _ready() -> void:
	for child in get_children():
		if child is ColorRect and child.has_meta("upgraded_color"):
			original_colors[child] = child.color

func refresh_appearance() -> void:
	for child in original_colors:
		child.color = child.get_meta("upgraded_color") if upgraded else original_colors[child]
	if has_node("Microphone"): $Microphone.visible = microphone
	for index in range(3):
		var trophy := get_node_or_null("Trophy%d" % index)
		if trophy != null: trophy.visible = index < trophy_count
