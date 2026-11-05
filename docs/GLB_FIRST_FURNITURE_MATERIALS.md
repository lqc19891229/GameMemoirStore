# GLB-first furniture finishing

The model itself must be the finished asset. This recipe produces a standalone
GLB with embedded Base Color, normal and metallic-roughness PNG textures.
It uses the current chair's 12 existing named mesh groups, color palette and
shared furniture library roughness/metallic parameters. It does not alter
mesh vertex data, UVs, normals, hierarchy or collision metadata.

Requires Python 3.12 and Pillow. Generate a preview:
python tools/models/bake_chair_gaming_materials.py --output chair_gaming_finished.glb

Open the finished GLB in Blender and inspect chair upholstery, seams, shell,
armrests, base and wheels. After approval:
python tools/models/bake_chair_gaming_materials.py --in-place

After baking in place, remove the MaterialProfile node from
scenes/room/seating/chair_gaming.tscn. Do not remove it before baking:
otherwise the existing chair will lose its current Godot PBR appearance.

The actual GLB has NOT been rewritten in this preparation PR because the
connected GitHub binary retrieval returned no file bytes for the large asset.
Run the recipe against the complete GLB checked out in the local repository.

All embedded images live in the GLB BIN chunk; no Godot runtime material
profile is needed after finalization. Player-specific material overrides
still work as a separate layer. Repeat this process for other furniture
to standardize import: meshes+UV+normals+finished PBR in GLB, then register
the furniture for use in Godot.
