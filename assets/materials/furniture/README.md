# Shared furniture materials (Godot 4.6)

This directory contains 12 shared StandardMaterial3D resources across 7 categories: leather, fabric, wood, metal, plastic, rubber and glass. They are lightweight shared PBR presets; some include procedural maps, while high-resolution scanned PBR textures are not included.

## Use in the editor

1. Enable **Furniture Material Library** in Project > Project Settings > Plugins if needed.
2. Open a furniture wrapper scene such as `res://scenes/room/seating/chair_gaming.tscn`.
3. For its imported GLB scene instance (the `Model` node), right-click and enable **Editable Children** before changing mesh child surfaces.
4. Open the **Furniture Materials** dock; choose a mesh/surface and a shared preset, then click **Apply surface override**.
5. Save the wrapper scene with Ctrl+S, reopen it and verify the override persists. Do not edit the source .glb.
6. To undo a material assignment, use the editor Undo or **Clear surface override**.

Shared presets are referenced by resource path and can be reused across furniture scenes. Editing a shared material changes every scene using that resource. To create a unique finish, duplicate the .tres first.

These presets do not replace the existing in-game `MemoirFurnitureFinishes` color overlays or furniture save IDs. Imported geometry, game catalog, furniture registration and existing scenes are untouched.

The project uses Godot 4.6 with GL Compatibility. The transparent glass preset is intended as a simple preview and may require adjustment for the renderer and individual mesh geometry. Realistic leather/fabric/wood microstructure needs proper UVs and corresponding PBR texture maps in a future art pass.

## P1: Procedural micro-surface normal textures

Leather, fabric, wood, and metal presets now reference four shared, tileable
`NoiseTexture2D` resources under `textures/`. The resources use seeded
`FastNoiseLite` height noise converted into normal textures by Godot.

- Leather: subtle pores at repeated UV scale.
- Fabric: denser, softly raised fiber-like variation.
- Wood: low-frequency anisotropic variation.
- Metal: low-strength brushed variation.

The effect is intentionally modest: real grain direction, stitched leather,
woven cloth and distinctive wood patterns will need authored UVs and high-quality
color/roughness/normal textures in a later art pass. These are procedural normal
microdetails, **not** photorealistic PBR scan assets.

`StandardMaterial3D` resource paths and names are unchanged; runtime RGB
tint, save data, previews, and the editor's material picker still target the
same presets. Godot creates the noise images when loading the materials, so
the first display in-editor may generate them asynchronously.

Validation:
`godot --headless --path . --script res://tests/life/test_furniture_materials.gd`
and visually inspect seating and table meshes using the Compatibility renderer.
UVs must be present for the effect; imported GLBs without UVs will not receive
the intended mapped detail.

## P1.2: Albedo and roughness microvariation

The eight leather, fabric, wood and metal presets now share an additional
**two noise textures per material family**, alongside the normal map:

- A near-white albedo modulation map that is **multiplied by** the user-selected
  base RGB without obscuring the chosen hue. The map values deliberately stay
  near white (approximately 0.80–1.0 depending on the family).
- A grayscale roughness multiplier (approximately 0.78–1.0) that produces
  subtle highlight breakup while retaining each preset's roughness scalar.

All maps are deterministic, seamless `NoiseTexture2D` resources with
`FastNoiseLite` and `Gradient` ramps. They use the preset's existing UV
repetition settings and are shared between furniture instances.

This is an incremental procedural surface finish, **not** authored wood
grain, fabric weave or photogrammetry. Smooth/no-UV GLB meshes may not show
the intended detail. Plastic, rubber and glass are unchanged.

The library resources and save-preset strings are stable; old RGB and
per-slot saved appearance data remain compatible.

Validation:
`godot --headless --path . --script res://tests/life/test_furniture_materials.gd`
Then inspect the gaming chair, a cloth seat and a wood table with the
Compatibility renderer under both bright and indirect light.

## P1.3: Seamless structured grayscale pattern textures

Four deterministic grayscale PNG pattern tiles replace the generic albedo
noise on eight presets: cellular leather pores, basket woven fabric,
directional linear wood grain and fine brushed metal. The pixels remain
near white, so they multiply player-selected RGB without replacing the hue.
All existing normal and roughness maps remain shared and unchanged.

These are stylized generated textures rather than photographic PBR scans.
The same material preset paths and save schema are preserved; no GLB files
are touched. Ensure Godot imports the new PNG assets before running tests.

Run:
`godot --headless --editor --path . --quit`
`godot --headless --path . --script res://tests/life/test_furniture_materials.gd`

Inspect the gaming chair and wooden furniture in GL Compatibility mode.
Visual quality depends on UV layout and mesh texel density.
