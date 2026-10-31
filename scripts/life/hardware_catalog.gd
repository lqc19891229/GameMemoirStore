class_name MemoirHardwareCatalog
extends Resource
## One inventory item may supply independent keyboard and mouse appearances.
@export var monitors: Dictionary[String, MemoirDeviceVisual] = {}
@export var computers: Dictionary[String, MemoirDeviceVisual] = {}
@export var keyboards: Dictionary[String, MemoirDeviceVisual] = {}
@export var mice: Dictionary[String, MemoirDeviceVisual] = {}

func visual_for(role: String, item_id: String) -> MemoirDeviceVisual:
	match role:
		"monitor": return monitors.get(item_id)
		"computer": return computers.get(item_id)
		"keyboard": return keyboards.get(item_id)
		"mouse": return mice.get(item_id)
	return null
