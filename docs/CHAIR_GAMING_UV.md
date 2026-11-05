# Game Chair: Texture UV / normal repair (P1.5)

The source `chair_gaming.glb` had **12 mesh primitives with POSITION
only**; none had `TEXCOORD_0` or `NORMAL`. As a result, the new leather,
fabric, metal and roughness pattern textures were not properly mapped to
this important furniture asset.

This revision adds:
- `TEXCOORD_0` UV coordinates on all 12 original mesh groups.
- Smooth averaged normals matching the existing triangle topology.
- Box-planar UV islands selected from each triangle's dominant face normal;
  opposite faces use mirrored orientation. Geometry is split *only where
  differing UV axes demand a seam*.
- Preserves mesh node names (`graphite`, `leather_pearl`,
  `leather_cream`, etc.), all original material definitions, triangle
  connectivity, coordinates, scene bounds and `PickArea/Hit`.

The file is larger because seam-safe vertices require additional vertex
attributes. Existing saved material settings use scene-node path and
surface index; neither is intended to change.

**Limitations:** This is automatic box-style UV mapping, not manually
authored upholstery islands. Texture grain orientation and repetition
should be visually checked on seat, back and armrests. Seam visibility,
especially on curved pieces, may need a further Blender art pass.
The model shape and built-in material colors remain the same.

## Validation

After pulling the changes, trigger a Godot reimport and run:

```bash
godot --headless --editor --path . --quit
godot --headless --path . --script res://tests/life/test_chair_gaming_uv.gd
godot --headless --path . --script res://tests/life/test_furniture_materials.gd
```

Then open `scenes/room/seating/chair_gaming.tscn` and apply one shared
leather or fabric preset to a relevant mesh surface. Confirm that the
albedo pattern and normal microstructure are visible and not stretched
or excessively repeated. Check custom RGB, U/V tiling, saving and
loading, and separate appearances for two chair instances.
