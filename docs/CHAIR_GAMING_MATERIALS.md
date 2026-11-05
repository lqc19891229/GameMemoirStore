# Game chair — authored PBR baseline (P1.6)

The GLB source geometry and names remain unchanged. Instead, the wrapper
`scenes/room/seating/chair_gaming.tscn` now has a `MaterialProfile` child
with a `@tool` script. This binds the twelve existing named GLB mesh groups
to independent instances of shared `StandardMaterial3D` presets.

| GLB group | Shared PBR preset | Color |
|---|---|---|
| graphite | plastic_black | #30343a |
| gunmetal | metal_black_matte | #61676d |
| rubber | rubber_black | #24282c |
| wheel_hub | metal_brushed_steel | #656b70 |
| steel | metal_brushed_steel | #9da2a6 |
| dark_shell | plastic_black | #222a30 |
| grey_inset | fabric_gray | #888b8d |
| leather_pearl | leather_white | #d4cec4 |
| leather_cream | leather_white | #e2dcd3 |
| stitch | fabric_beige | #b5aaa0 |
| edge_welt | leather_black | #77797b |
| leather_shadow | leather_white | #bbb6b0 |

The upholstered surfaces use the library's existing PBR pattern/albedo,
roughness and normal maps with the UV coordinates added in #104. Metal
surfaces use shared brushed-metal textures. Plastic, rubber and trim use
suitable matte presets. The per-instance tint does not change the shared
preset resources.

**Runtime player customization continues to work.** The appearance manager
overrides any surface baseline when there is a saved UID-specific choice.
Removing that choice restores the baseline, not the original flat GLB material.

This approach deliberately keeps the source GLB portable and its hierarchy,
triangle geometry, surface indices, collision bounds and serialized saved
material slot keys stable. Godot `.tres` material resources cannot be
embedded as native external references inside a portable `.glb` file;
the wrapper is the integration point used by the actual game.

Local validation after reimport:

```bash
godot --headless --editor --path . --quit
godot --headless --path . --script res://tests/life/test_chair_gaming_uv.gd
godot --headless --path . --script res://tests/life/test_chair_gaming_materials.gd
godot --headless --path . --script res://tests/life/test_furniture_materials.gd
```

Inspect material hue and UV seams on the chair in the GL Compatibility
renderer. The raw GLB, viewed outside Godot, still shows its embedded
original materials; only the game wrapper uses the shared Godot PBR library.
