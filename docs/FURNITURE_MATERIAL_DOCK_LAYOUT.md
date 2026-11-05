# Furniture Materials dock: height regression fix

The Godot editor's furniture manager provides three bottom tabs:
**家具资源**, **家具导入**, **家具注册**. The Furniture Material Library
adds a side dock to the Inspector area.

Previously, the side dock was a bare `VBoxContainer` holding two
`ItemList` widgets with explicit minimum heights (180 px + 190 px).
The aggregate minimum height could exceed the available dock height in a
short editor window, and the editor layout manager could hide its bottom
panel, even if the material library tab was not selected.

This change wraps the dock content in a `ScrollContainer` with a zero
minimum height. The material lists retain their usable heights, but they
are now scrollable inside the side dock without controlling the overall
editor vertical minimum size.

No changes are made to the furniture-manager addon, save files, material
presets, scenes, models or player customization.

## Manual verification (Godot 4.6)

1. Enable both `Furniture Manager` and `Furniture Material Library`
   in Project Settings > Plugins.
2. Reduce the Godot editor window height to approximately 720 px or less.
3. Verify the bottom tabs **家具资源**, **家具导入**, **家具注册** stay
   visible and can open.
4. Open a furniture scene, select the material dock and scroll through
   surfaces and presets. Verify applying/clearing a surface still works.
5. Disable/enable the material library again and repeat.
