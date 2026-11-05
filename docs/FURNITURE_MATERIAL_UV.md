# Furniture material UV controls — P1.4

The in-game furniture paint palette now includes per-surface U and V repeat
multipliers (0.25–8.0) plus horizontal and vertical mirroring. Existing
material presets retain their base UV scale. The controls multiply the
original scale for the chosen mesh surface, without editing shared presets,
other furniture instances or imported GLB assets.

The existing `furniture_materials` dictionary uses optional keys:
`tile_u`, `tile_v` (finite numbers in [0.25, 8.0]),
`flip_u`, `flip_v` (bools). Old saves without these fields render at
1.0 repeat and no mirroring. All values pass through the existing sanitizer
and participate in undo/redo, layout Apply/Cancel, duplication and JSON save.

An informational label reports whether the selected surface contains UV
coordinates. Meshes without authored UVs may not show the patterns correctly.
A flipped (negative) UV scale mirrors tiled patterns, but **does not rotate
UVs by 90 degrees**. Proper cross-axis rotation or consistent wood grain
direction across arbitrary geometry requires authored UVs or a separate
shader-based approach, intentionally out of scope.

Local checks:
`godot --headless --editor --path . --quit`
`godot --headless --path . --script res://tests/life/test_furniture_materials.gd`

Then select `chair_gaming` in room editing, apply leather or fabric, adjust
U/V factors, save the room, reload and verify the appearance.
