# Material editing usability improvements

This change builds on the already merged runtime material system (#98).

- The in-game material picker now displays localized material preset names.
- Mesh surface options show human-readable hints, original imported mesh/material names and surface indices. The original mesh path is still available as each option tooltip.
- Labels are only heuristic: unknown GLB mesh names remain identifiable as generic surfaces, rather than incorrectly claiming a specific chair part.
- The RGB picker now sets the desired albedo color directly. Previously the selected RGB was multiplied by the base preset color, making dark leather/plastic impossible to tint brightly.
- The PBR roughness, metallic properties, alpha and texture maps are retained from the shared preset.
- Save keys, the 12 preset IDs and old furniture UIDs remain unchanged.

To verify: enter furniture editing, choose `chair_gaming`, open the paint tool and select a mesh. Apply black leather with white RGB and confirm the surface is light-colored; compare with pure black RGB. Check the surface identifier in the tooltip, then save/reload the room. Unknown imported GLB node names will remain generic until a manual per-model semantic mapping is authored.

Headless test: `godot --headless --path . --script res://tests/life/test_furniture_materials.gd`.
