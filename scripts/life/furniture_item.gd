extends Button
## One texture per furniture item; optional sprite overlays carry actual gameplay state.
@export_enum("computer", "desk", "peripheral", "cabinet", "decor") var kind := "computer"
## Optional upgraded artwork. Leave empty to use a subtle warm tint on the base sprite.
@export var upgraded_texture: Texture2D
var upgraded := false
var trophy_count := 0
var microphone := false
var base_texture: Texture2D

func _ready() -> void:
	base_texture = $Art.texture

func refresh_appearance() -> void:
	$Art.texture = upgraded_texture if upgraded and upgraded_texture != null else base_texture
	$Art.self_modulate = Color(1.0, 0.97, 0.87) if upgraded and upgraded_texture == null else Color.WHITE
	var microphone_node := get_node_or_null("Microphone")
	if microphone_node != null: microphone_node.visible = microphone
	for index in range(3):
		var trophy := get_node_or_null("Trophy%d" % index)
		if trophy != null: trophy.visible = index < trophy_count
