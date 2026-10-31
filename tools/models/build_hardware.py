"""Blender 3.6.23 LTS: blender --background --threads 1 --factory-startup --python tools/models/build_hardware.py

Offline authoring workflow for the desktop showcase assets.
Coordinates are Godot X-right, Y-up, Z-front, in metres.
The script exports nine hardware variants plus the detailed room chair.
"""
import bpy
import math
import random
from pathlib import Path

PROJECT = Path(__file__).resolve().parents[2]
OUTPUT = PROJECT / "assets/models/hardware"
ROOM_OUTPUT = PROJECT / "assets/models/room"
SOURCE = Path(__file__).resolve().parent / "hardware.blend"
OUTPUT.mkdir(parents=True, exist_ok=True)
ROOM_OUTPUT.mkdir(parents=True, exist_ok=True)

bpy.ops.object.select_all(action="SELECT")
bpy.ops.object.delete(use_global=False)
random.seed(7)


def material(name, color, metallic=0.0, roughness=.55, emission=None, strength=0.0, alpha=1.0):
    mat = bpy.data.materials.new(name)
    mat.diffuse_color = (*color, alpha)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = (*color, alpha)
    bsdf.inputs["Metallic"].default_value = metallic
    bsdf.inputs["Roughness"].default_value = roughness
    if alpha < 1.0:
        bsdf.inputs["Alpha"].default_value = alpha
        if hasattr(mat, "blend_method"):
            mat.blend_method = "BLEND"
        if hasattr(mat, "surface_render_method"):
            mat.surface_render_method = "BLENDED"
    if emission is not None:
        socket = bsdf.inputs.get("Emission")
        if socket is None:
            socket = bsdf.inputs.get("Emission Color")
        if socket is not None:
            socket.default_value = (*emission, 1.0)
        emission_strength = bsdf.inputs.get("Emission Strength")
        if emission_strength is not None:
            emission_strength.default_value = strength
    return mat


cream = material("Aged ivory plastic", (.66, .60, .43))
edge = material("Warm ivory edge", (.80, .74, .57))
dark = material("Recesses and rubber", (.035, .052, .049))
sage = material("Sage modifier keys", (.18, .24, .19))
charcoal = material("Charcoal shell", (.065, .085, .09), .12, .45)
silver = material("Brushed silver", (.47, .52, .49), .55, .37)
glass = material("Smoked tempered glass", (.055, .12, .15), .18, .16, alpha=.26)
green = material("Power LED", (.19, .71, .32), .05, .25, (.12, .9, .32), 1.8)
cyan = material("RGB cyan", (.08, .65, .88), .05, .25, (.03, .55, 1.0), 2.4)
magenta = material("RGB magenta", (.72, .12, .58), .05, .25, (.9, .04, .48), 2.0)
blue = material("RGB blue", (.12, .28, .88), .05, .25, (.04, .12, 1.0), 2.0)
warm_led = material("Warm LED", (.95, .55, .19), .0, .3, (1.0, .36, .08), 1.2)
oak = material("Oak pixel grain", (.40, .21, .08), 0, .7)
rubber = material("Soft black rubber", (.025, .032, .035), 0, .92)
fabric = material("Deep graphite fabric", (.075, .095, .105), 0, .92)
fabric_light = material("Slate fabric panels", (.16, .20, .22), 0, .9)
stitch = material("Fabric seam", (.48, .50, .47), 0, .85)
gold = material("Brushed warm metal", (.56, .39, .17), .62, .38)

# A packed, reproducible 64-pixel wood material with nearest-neighbour sampling.
image = bpy.data.images.new("Oak palette pixels", width=64, height=64)
pixels = []
for y in range(64):
    band = .04 * math.sin(y * 1.8) + random.uniform(-.022, .022)
    for x in range(64):
        value = round((band + random.uniform(-.012, .012)) * 64) / 64
        pixels.extend((.40 + value, .21 + value * .6, .08 + value * .25, 1))
image.pixels = pixels
image.pack()
texture = oak.node_tree.nodes.new("ShaderNodeTexImage")
texture.image = image
texture.interpolation = "Closest"
oak.node_tree.links.new(texture.outputs["Color"], oak.node_tree.nodes["Principled BSDF"].inputs["Base Color"])

current = None


def finish(obj, name, mat, bevel=0.0):
    obj.name = name
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    bpy.ops.object.transform_apply(location=True, rotation=False, scale=False)
    for collection in list(obj.users_collection):
        collection.objects.unlink(obj)
    current.objects.link(obj)
    obj.data.materials.append(mat)
    if bevel:
        modifier = obj.modifiers.new("Manufactured edge radius", "BEVEL")
        modifier.width = bevel
        modifier.segments = 2
        bpy.context.view_layer.objects.active = obj
        bpy.ops.object.modifier_apply(modifier=modifier.name)
        if hasattr(obj.data, "use_auto_smooth"):
            obj.data.use_auto_smooth = True
            normal = obj.modifiers.new("Weighted corner normals", "WEIGHTED_NORMAL")
            bpy.ops.object.modifier_apply(modifier=normal.name)
    return obj


def box(name, center, size, mat, bevel=.004, rotate_y=0.0, rotate_z=0.0):
    x, y, z = center
    width, height, depth = size
    bpy.ops.mesh.primitive_cube_add(size=1, location=(x, -z, y))
    obj = bpy.context.object
    obj.scale = (width, depth, height)
    obj.rotation_euler.z = rotate_y
    obj.rotation_euler.y = -rotate_z
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    return finish(obj, name, mat, bevel)


def cylinder(name, center, radius, depth, mat, axis="z", vertices=20):
    x, y, z = center
    bpy.ops.mesh.primitive_cylinder_add(vertices=vertices, radius=radius, depth=depth, location=(x, -z, y))
    obj = bpy.context.object
    if axis == "z":
        obj.rotation_euler.x = math.pi / 2
    elif axis == "x":
        obj.rotation_euler.y = math.pi / 2
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    return finish(obj, name, mat, .001)


def sphere(name, center, scale, mat, segments=20, rings=12):
    x, y, z = center
    bpy.ops.mesh.primitive_uv_sphere_add(segments=segments, ring_count=rings, radius=1, location=(x, -z, y))
    obj = bpy.context.object
    obj.scale = (scale[0], scale[2], scale[1])
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    return finish(obj, name, mat)


def torus(name, center, major, minor, mat, axis="z"):
    x, y, z = center
    bpy.ops.mesh.primitive_torus_add(
        major_segments=28, minor_segments=8, major_radius=major, minor_radius=minor,
        location=(x, -z, y)
    )
    obj = bpy.context.object
    if axis == "z":
        obj.rotation_euler.x = math.pi / 2
    elif axis == "x":
        obj.rotation_euler.y = math.pi / 2
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    return finish(obj, name, mat)


def begin(name):
    global current
    current = bpy.data.collections.new(name)
    bpy.context.scene.collection.children.link(current)


def fan(name, center, radius, frame, glow, axis="z"):
    x, y, z = center
    torus(name + " illuminated ring", center, radius * .88, radius * .075, glow, axis)
    cylinder(name + " hub", center, radius * .20, .018, frame, axis, vertices=20)
    if axis == "z":
        for index in range(5):
            angle = math.tau * index / 5
            px = x + math.cos(angle) * radius * .48
            py = y + math.sin(angle) * radius * .48
            box(name + " blade", (px, py, z), (radius * .52, radius * .13, .012),
                frame, .003, rotate_z=angle)


def case(upgrade=False):
    shell = charcoal if upgrade else cream
    trim = silver if upgrade else edge
    box("Steel chassis", (0, .50, 0), (.46, 1.0, .82), shell, .018)
    box("Front fascia", (0, .50, .421), (.43, .97, .035), trim, .012)

    if upgrade:
        # Three front intake fans and a smoked side window reveal the internal build.
        box("Front fan recess", (0, .50, .444), (.39, .78, .012), dark, .008)
        for y in [.72, .50, .28]:
            fan("Front RGB fan", (0, y, .454), .073, charcoal, cyan if y != .50 else magenta)
        box("Front I/O plate", (0, .91, .445), (.22, .075, .012), silver, .004)
        cylinder("Power key", (-.075, .91, .456), .018, .012, dark, vertices=16)
        cylinder("Power LED", (.075, .91, .456), .007, .012, green, vertices=12)
        for x in [-.045, 0, .045]:
            box("USB port", (x, .86, .454), (.026, .009, .006), dark, .001)

        # The side panel is inside the existing 0.47 m device bounds.
        box("Tempered side glass", (.231, .52, -.005), (.006, .72, .64), glass, .002)
        for y in [.15, .89]:
            box("Glass frame horizontal", (.232, y, -.005), (.006, .025, .68), silver, .002)
        for z in [-.34, .33]:
            box("Glass frame vertical", (.232, .52, z), (.006, .72, .025), silver, .002)

        box("Motherboard tray", (.184, .52, -.02), (.018, .65, .56), dark, .003)
        box("Motherboard PCB", (.197, .53, -.02), (.012, .56, .46), sage, .002)
        box("Graphics card shroud", (.155, .31, -.035), (.105, .12, .49), charcoal, .008)
        box("GPU accent", (.211, .31, -.035), (.006, .035, .38), cyan, .002)
        for z in [-.15, .08]:
            fan("GPU cooling fan", (.206, .31, z), .045, dark, blue, axis="x")
        box("CPU block", (.208, .68, -.02), (.035, .17, .17), silver, .006)
        fan("CPU cooler", (.214, .68, -.02), .062, dark, cyan, axis="x")
        for z in [-.22, -.15, -.08]:
            box("RGB memory module", (.209, .69, z), (.014, .20, .025), silver, .002)
            box("Memory light bar", (.218, .69, z), (.005, .15, .008), magenta, .001)
        box("Power supply", (.17, .17, -.20), (.12, .16, .28), dark, .006)
        box("Cable channel", (.19, .42, .22), (.018, .06, .20), rubber, .004)
        for z in [-.22, -.16, -.10, -.04, .02, .08]:
            box("Top vent", (0, .992, z), (.30, .008, .014), dark, .001)
        for x in [-.16, .16]:
            for z in [-.28, .28]:
                cylinder("Panel screw", (x, .52, z), .008, .008, silver, axis="x", vertices=10)
    else:
        # The starter model keeps a warm retro identity rather than imitating the RGB upgrade.
        for y in [.83, .67]:
            box("Drive recess", (0, y, .444), (.35, .13, .014), dark, .003)
            box("Optical drawer", (0, y + .008, .454), (.326, .096, .012), shell, .003)
            box("Eject key", (.13, y - .026, .465), (.032, .012, .012), trim, .001)
            box("Disc seam", (-.018, y + .036, .463), (.25, .003, .004), dark, .0005)
        cylinder("Power surround", (0, .39, .455), .043, .013, dark)
        cylinder("Power key", (0, .39, .467), .032, .012, trim)
        cylinder("Power indicator", (.074, .39, .467), .008, .013, green, vertices=8)
        for y in [.13 + i * .025 for i in range(6)]:
            box("Front intake", (0, y, .455), (.30, .008, .009), dark, .001)
        for row in range(8):
            box("Side ventilation", (.232, .30 + row * .031, -.08), (.006, .012, .30), dark, .001)

    # Shared rear I/O, top ventilation, feet and subtle assembly hardware.
    box("Rear panel", (0, .50, -.418), (.41, .94, .014), silver, .003)
    box("PSU grille", (0, .81, -.43), (.28, .22, .012), dark, .002)
    for col in range(7):
        box("PSU slat", (-.12 + col * .04, .81, -.44), (.012, .19, .01), shell, .001)
    box("Rear I/O", (-.08, .51, -.436), (.13, .25, .012), dark, .001)
    for row in range(4):
        box("Rear port", (-.08, .42 + row * .06, -.446), (.07, .025, .01), silver, .001)
    for x in [-.16, .16]:
        for z in [-.28, .28]:
            box("Rubber foot", (x, .018, z), (.07, .035, .10), rubber, .004)


def monitor(lcd=False):
    shell = silver if lcd else cream
    trim = charcoal if lcd else edge
    # Stable base, neck and VESA transition; the screen remains a live Godot quad.
    box("Stand base", (0, .032, 0), (.75, .064, .44), shell, .022)
    box("Stand neck", (0, .19, -.04), (.18, .28, .16), shell, .018)
    box("VESA mount", (0, .34, -.06), (.26, .12, .18), dark, .008)

    width, height, depth = (1.60, 1.02, .10) if lcd else (1.58, 1.05, .56)
    center_y = .84
    front = .075 if lcd else .325
    center_z = front - depth / 2 - .02
    box("Display housing", (0, center_y, center_z), (width, height, depth), shell, .035 if lcd else .065)
    screen_w, screen_h = (1.42, .8875) if lcd else (1.28, .80)
    box("Recessed screen backing", (0, center_y, front - .025), (screen_w + .01, screen_h + .01, .018), glass, .004)

    horizontal = (width - screen_w) / 2
    for x in [-(screen_w + horizontal) / 2, (screen_w + horizontal) / 2]:
        box("Side bezel", (x, center_y, front - .012), (horizontal, height, .055), shell, .014)
    vertical = (height - screen_h) / 2
    for y in [center_y - (screen_h + vertical) / 2, center_y + (screen_h + vertical) / 2]:
        box("Top bottom bezel", (0, y, front - .012), (screen_w, vertical, .055), shell, .014)

    cylinder("Tilt hinge", (0, .34, -.10), .075, .18, gold if lcd else trim, axis="x")
    box("Cable guide", (0, .30, -.17), (.055, .12, .045), rubber, .006)
    for x in [-.55 + i * .11 for i in range(11)]:
        box("Rear cooling rib", (x, center_y + .29, front - depth - .026), (.045, .19, .012), dark, .001)
    box("Rear label", (0, center_y - .12, front - depth - .032), (.35, .12, .012), trim, .002)

    if lcd:
        sphere("Webcam lens", (0, center_y + height / 2 - .045, front + .006), (.012, .012, .006), dark, 12, 8)
        sphere("Status LED", (.68, center_y - height / 2 + .035, front + .006), (.006, .006, .004), green, 12, 8)
        box("Lower logo inset", (0, center_y - height / 2 + .035, front + .004), (.16, .018, .006), dark, .002)
        box("Rear spine", (0, center_y, center_z - depth / 2 - .008), (.18, .58, .035), silver, .008)
        for x in [-.055, 0, .055]:
            box("Rear connector", (x, .28, center_z - depth / 2 - .028), (.025, .018, .012), dark, .001)
    else:
        for x in [-.72, -.68, -.64, .64, .68, .72]:
            for y in [.56, .60, .64, .68, .72, .76, .80, .84, .88, .92, .96, 1.00, 1.04, 1.08]:
                cylinder("Speaker perforation", (x, y, front + .006), .003, .004, dark, vertices=8)
        for index in range(3):
            cylinder("CRT control", (.70, .43 + index * .045, front + .008), .012, .008, trim, vertices=12)
        box("CRT lower badge", (0, .36, front + .008), (.22, .025, .008), gold, .002)


def keyboard(upgrade=False):
    shell = charcoal if upgrade else cream
    key = fabric_light if upgrade else edge
    accent = cyan if upgrade else sage
    box("Keyboard shell", (0, .028, 0), (1.25, .056, .48), shell, .015)
    box("RGB underglow bed", (0, .060, -.005), (1.20, .012, .42), dark, .003)
    box("Key bed", (0, .067, -.005), (1.20, .012, .42), accent if upgrade else dark, .003)

    for row in range(6):
        z = -.185 + row * .068
        for col in range(20):
            if row == 5 and 3 <= col <= 10:
                continue
            x = -.575 + col * .060
            modifier = col in [0, 1, 12, 13] or row == 0
            cap_mat = accent if modifier and upgrade else (sage if modifier else key)
            box("Individual keycap", (x, .082, z), (.052, .028, .052), cap_mat, .004)
            if (row + col) % 3 == 0:
                box("Key legend horizontal", (x, .097, z), (.018, .002, .003), dark, .0005)
                box("Key legend vertical", (x - .006, .097, z + .004), (.003, .002, .010), dark, .0005)

    box("Space bar", (-.185, .082, .155), (.472, .028, .052), key, .004)
    for x in [.38, .43, .48]:
        cylinder("Keyboard status LED", (x, .071, -.211), .003, .006, green, axis="y", vertices=8)
    for x in [-.60, .60]:
        box("Side RGB strip", (x, .045, 0), (.012, .014, .36), cyan if upgrade else warm_led, .002)
    cylinder("Volume control", (.55, .085, -.18), .024, .018, gold if upgrade else dark, axis="y", vertices=20)
    for x in [-.48, .48]:
        box("Rear keyboard foot", (x, .012, -.205), (.12, .024, .035), rubber, .004)


def mouse(upgrade=False):
    shell = charcoal if upgrade else cream
    accent = cyan if upgrade else sage
    sphere("Ergonomic mouse shell", (0, .064, 0), (.091, .060, .151), shell, 28, 16)
    for x in [-.030, .030]:
        box("Mouse primary button", (x, .105, .045), (.056, .012, .088), shell, .012)
    cylinder("Scroll wheel", (0, .116, .025), .014, .032, rubber, axis="x", vertices=16)
    for index in range(5):
        box("Scroll grip", (0, .129, .012 + index * .006), (.006, .002, .002), silver, .0005)
    for x in [-.085, .085]:
        box("Side grip", (x, .065, -.015), (.010, .035, .085), rubber, .004)
    for index in range(2):
        box("Side navigation key", (.088 if upgrade else -.088, .078, -.035 + index * .045), (.008, .018, .026), accent, .003)
    sphere("DPI key", (0, .124, -.045), (.012, .006, .012), gold, 12, 8)
    box("Rear RGB accent", (0, .104, -.112), (.070, .008, .012), cyan if upgrade else green, .003)
    sphere("Optical sensor", (0, .006, -.055), (.012, .004, .012), silver, 12, 8)
    for x in [-.06, .06]:
        box("Mouse glide foot", (x, .006, .095), (.025, .006, .035), rubber, .002)


def desk():
    # 4.8 x 2.3 m tabletop and original 0.78 m working height are unchanged.
    box("Rounded oak desktop", (0, .73, 0), (4.8, .10, 2.26), oak, .035)
    box("Front edge inlay", (0, .704, 1.12), (4.70, .035, .018), gold, .006)
    box("Rear cable channel", (0, .60, -.92), (4.25, .16, .12), dark, .012)
    for x in [-2.18, 2.18]:
        for z in [-.91, .91]:
            box("Metal desk leg", (x, .35, z), (.12, .70, .12), silver, .014)
            box("Rubber desk foot", (x, .025, z), (.16, .05, .16), rubber, .012)
    box("Rear support rail", (0, .56, -.91), (4.35, .12, .10), charcoal, .012)
    for x in [-1.62, 1.62]:
        box("Under desk drawer", (x, .58, -.60), (.78, .22, .42), dark, .012)
        box("Drawer face", (x, .58, -.382), (.72, .17, .018), silver, .006)
        box("Drawer handle", (x, .58, -.365), (.18, .018, .018), dark, .004)
    for x in [-1.85, 1.85]:
        cylinder("Cable grommet", (x, .784, -.92), .035, .008, dark, axis="y", vertices=24)
        torus("Grommet metal rim", (x, .788, -.92), .032, .003, gold, axis="y")
    box("Under desk ambient strip", (0, .662, 1.105), (3.8, .012, .012), cyan, .003)
    for x in [-2.10, 2.10]:
        box("Side apron", (x, .63, 0), (.06, .16, 1.85), oak, .012)


def chair():
    # Detailed ergonomic chair, kept inside the existing 1.02 x 1.50 x 0.84 bounds.
    box("Seat support plate", (0, .49, -.02), (.42, .08, .42), dark, .012)
    cylinder("Gas lift", (0, .29, -.02), .045, .42, silver, axis="y", vertices=24)
    cylinder("Gas lift collar", (0, .46, -.02), .072, .06, gold, axis="y", vertices=24)

    for index in range(5):
        angle = math.tau * index / 5
        x = math.cos(angle) * .19
        z = -.02 + math.sin(angle) * .19
        box("Five star base spoke", (x, .105, z), (.075, .075, .43), dark, .014, rotate_y=angle)
        wheel_x = math.cos(angle) * .34
        wheel_z = -.02 + math.sin(angle) * .34
        sphere("Caster housing", (wheel_x, .065, wheel_z), (.055, .055, .055), rubber, 16, 10)
        cylinder("Caster axle", (wheel_x, .065, wheel_z), .025, .07, silver, axis="x", vertices=12)

    box("Seat shell", (0, .56, -.02), (.82, .18, .72), dark, .045)
    box("Seat cushion", (0, .665, -.035), (.75, .105, .65), fabric, .055)
    box("Seat centre panel", (0, .721, -.055), (.43, .012, .48), fabric_light, .045)
    for x in [-.30, .30]:
        box("Seat side bolster", (x, .70, -.03), (.12, .075, .58), fabric_light, .035)
    for x in [-.28, .28]:
        box("Seat stitch line", (x, .729, -.04), (.006, .004, .48), stitch, .002)

    # Backrest shell and layered cushions, facing the original -Z sitting direction.
    box("Backrest frame", (0, 1.06, .265), (.82, .82, .15), dark, .045)
    box("Backrest cushion", (0, 1.07, .185), (.72, .76, .105), fabric, .055)
    box("Backrest centre panel", (0, 1.08, .126), (.40, .63, .012), fabric_light, .025)
    for x in [-.31, .31]:
        box("Shoulder wing", (x, 1.13, .18), (.13, .56, .12), fabric_light, .035)
    box("Lumbar support", (0, .91, .105), (.55, .18, .08), fabric_light, .035)
    box("Headrest cushion", (0, 1.405, .20), (.44, .17, .12), fabric_light, .045)
    box("Headrest badge", (0, 1.405, .132), (.12, .035, .008), gold, .004)
    for x in [-.24, .24]:
        box("Backrest seam", (x, 1.08, .116), (.006, .52, .004), stitch, .001)
    box("Lower back seam", (0, .79, .12), (.48, .006, .004), stitch, .001)

    for x in [-.43, .43]:
        cylinder("Armrest support", (x, .70, -.02), .027, .22, silver, axis="y", vertices=16)
        box("Armrest pad", (x, .825, -.02), (.10, .075, .57), fabric_light, .025)
        box("Armrest trim", (x, .865, -.02), (.07, .008, .43), gold, .004)
    box("Tilt mechanism", (0, .49, -.02), (.28, .08, .34), silver, .012)
    box("Lumbar badge", (0, .93, .058), (.11, .035, .008), cyan, .003)


builders = {
    "case_beige": lambda: case(False),
    "case_charcoal": lambda: case(True),
    "monitor_crt": lambda: monitor(False),
    "monitor_lcd": lambda: monitor(True),
    "keyboard_beige": lambda: keyboard(False),
    "keyboard_charcoal": lambda: keyboard(True),
    "mouse_beige": lambda: mouse(False),
    "mouse_charcoal": lambda: mouse(True),
    "desk": desk,
    "chair": chair,
}

for name, build in builders.items():
    begin(name)
    build()
    # Join by material for compact imported scenes; editability remains in hardware.blend.
    groups = {}
    for obj in list(current.objects):
        groups.setdefault(obj.data.materials[0].name, []).append(obj)
    for label, objects in groups.items():
        bpy.ops.object.select_all(action="DESELECT")
        for obj in objects:
            obj.select_set(True)
        bpy.context.view_layer.objects.active = objects[0]
        bpy.ops.object.join()
        bpy.context.object.name = name + "_" + label.replace(" ", "_")

    bpy.ops.object.select_all(action="DESELECT")
    for obj in current.objects:
        obj.select_set(True)
    target = ROOM_OUTPUT if name == "chair" else OUTPUT
    bpy.ops.export_scene.gltf(
        filepath=str(target / f"{name}.glb"),
        export_format="GLB",
        use_selection=True,
        export_yup=True,
        export_apply=True,
        export_cameras=False,
        export_lights=False,
    )

for collection in bpy.data.collections:
    if collection.name in builders:
        collection.hide_viewport = collection.name != "case_beige"
for obj in bpy.data.objects:
    obj.select_set(False)
for obj in bpy.data.collections["case_beige"].objects:
    obj.select_set(True)
bpy.context.view_layer.objects.active = next(iter(bpy.data.collections["case_beige"].objects))
for screen in bpy.data.screens:
    for area in screen.areas:
        if area.type == "VIEW_3D":
            area.spaces.active.region_3d.view_distance = 2.4
            area.spaces.active.region_3d.view_location = (0, 0, .5)
bpy.context.preferences.filepaths.save_version = 0
bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE), compress=True)
print("DESKTOP_SHOWCASE_MODELS_COMPLETE", OUTPUT, ROOM_OUTPUT)
