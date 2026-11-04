# Shared furniture materials (Godot 4.6)

This directory contains 12 shared StandardMaterial3D resources across 7 categories: leather, fabric, wood, metal, plastic, rubber and glass. They are lightweight parameter-only PBR presets; high-resolution texture maps are not included.

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
