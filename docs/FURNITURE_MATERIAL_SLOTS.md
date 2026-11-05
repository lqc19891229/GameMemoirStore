# Runtime furniture material slots (P0)

The material library PR also adds per-instance, per-mesh-surface PBR customization.

- In **room edit mode**, select a placed piece of furniture and click the existing paint/color tool.
- Below the original whole-furniture color swatches, select a mesh surface, a shared PBR preset and an RGB/HEX color.
- Click **应用部件材质** to apply, or **恢复部件原始材质** to remove the per-surface override.
- Undo/redo and Apply/Cancel room editing use the existing layout transaction.
- Each inventory UID has its own `furniture_materials` dictionary; old save files default to an empty dictionary. The original `furniture_colors` remains backward-compatible.
- Duplicating furniture or a selected group copies the current per-surface appearance into the new UID, without sharing mutable material instances.
- Resources are duplicated at runtime before tinting, so editing one chair cannot recolor another.
- Imported mesh surface paths are keys. Re-exporting a GLB with renamed mesh nodes or reordered surfaces may orphan some saved overrides; missing keys are ignored.

To try: purchase/place `chair_gaming`, enter room editing, select it, open the paint tool, then change a visible surface to `leather/leather_black` or `fabric/fabric_gray`. Apply room layout, save and reload.

This P0 introduces parameter-based materials only. It does not contain high-resolution PBR maps, mesh-semantic automatic classification or a full multi-part chair UX. Existing whole-object color behavior is retained for surfaces not customized. If both legacy whole-object color and a surface override are active on the same mesh, the surface override takes precedence on that mesh.

Smoke test locally with Godot 4.6:
`godot --headless --path . --script res://tests/life/test_furniture_materials.gd`
`godot --headless --path . --script res://tests/life/test_furniture_catalog.gd`

Also visually test the game chair because imported mesh names and renderer appearance need an actual editor/game runtime.
