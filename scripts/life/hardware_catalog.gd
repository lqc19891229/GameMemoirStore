class_name MemoirHardwareCatalog
extends Resource
## One inventory item may supply independent keyboard and mouse appearances.
@export var monitors: Dictionary[String, MemoirDeviceModel] = {}
@export var computers: Dictionary[String, MemoirDeviceModel] = {}
@export var keyboards: Dictionary[String, MemoirDeviceModel] = {}
@export var mice: Dictionary[String, MemoirDeviceModel] = {}

func visual_for(role: String, item_id: String) -> MemoirDeviceModel:
	match role:
		"monitor": return monitors.get(item_id)
		"computer": return computers.get(item_id)
		"keyboard": return keyboards.get(item_id)
		"mouse": return mice.get(item_id)
	return null
