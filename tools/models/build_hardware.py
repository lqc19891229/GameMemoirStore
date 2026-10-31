"""Blender 3.6 LTS: blender --background --factory-startup --python tools/models/build_hardware.py

Authoring-only workflow. Saves editable Blender source and small reusable GLBs.
Coordinates in helpers are Godot X-right, Y-up, Z-front, in metres.
"""
import bpy
import math
import random
from pathlib import Path

PROJECT = Path(__file__).resolve().parents[2]
OUTPUT = PROJECT / 'assets/models/hardware'
SOURCE = Path(__file__).resolve().parent / 'hardware.blend'
OUTPUT.mkdir(parents=True, exist_ok=True)
bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete(use_global=False)
random.seed(7)

def material(name, color, metallic=0.0, roughness=.55):
    m=bpy.data.materials.new(name);m.diffuse_color=(*color,1);m.use_nodes=True
    node=m.node_tree.nodes.get('Principled BSDF')
    node.inputs['Base Color'].default_value=(*color,1)
    node.inputs['Metallic'].default_value=metallic
    node.inputs['Roughness'].default_value=roughness
    return m

cream=material('Aged ivory plastic',(.66,.60,.43))
edge=material('Warm ivory edge',(.80,.74,.57))
dark=material('Recesses and rubber',(.035,.052,.049))
sage=material('Sage modifier keys',(.18,.24,.19))
charcoal=material('Charcoal shell',(.065,.085,.09),.12,.45)
silver=material('Brushed silver',(.47,.52,.49),.55,.37)
glass=material('Screen glass',(.016,.055,.057),.12,.22)
green=material('Power LED',(.19,.71,.32),.1,.25)
oak=material('Oak pixel grain',(.40,.21,.08),0,.7)
# A packed, reproducible 64-pixel material, rather than a photo texture.
image=bpy.data.images.new('Oak palette pixels',width=64,height=64)
pixels=[]
for y in range(64):
    band=.04*math.sin(y*1.8)+random.uniform(-.022,.022)
    for x in range(64):
        v=round((band+random.uniform(-.012,.012))*64)/64
        pixels.extend((.40+v,.21+v*.6,.08+v*.25,1))
image.pixels=pixels;image.pack()
tex=oak.node_tree.nodes.new('ShaderNodeTexImage');tex.image=image;tex.interpolation='Closest'
oak.node_tree.links.new(tex.outputs['Color'],oak.node_tree.nodes['Principled BSDF'].inputs['Base Color'])

current=None
def finish(obj,name,mat,bevel=0):
    obj.name=name
    for collection in list(obj.users_collection):collection.objects.unlink(obj)
    current.objects.link(obj)
    obj.data.materials.append(mat)
    if bevel:
        modifier=obj.modifiers.new('Small manufactured edge','BEVEL');modifier.width=bevel;modifier.segments=2
        bpy.context.view_layer.objects.active=obj
        bpy.ops.object.modifier_apply(modifier=modifier.name)
        if hasattr(obj.data,'use_auto_smooth'):obj.data.use_auto_smooth=True
        normal=obj.modifiers.new('Weighted normals','WEIGHTED_NORMAL')
        bpy.ops.object.modifier_apply(modifier=normal.name)
    return obj

def box(name,center,size,mat,bevel=.004):
    x,y,z=center;w,h,d=size
    bpy.ops.mesh.primitive_cube_add(size=1,location=(x,-z,y))
    obj=bpy.context.object;obj.scale=(w,d,h)
    bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    return finish(obj,name,mat,bevel)

def cylinder(name,center,radius,depth,mat,axis='z',vertices=16):
    x,y,z=center
    bpy.ops.mesh.primitive_cylinder_add(vertices=vertices,radius=radius,depth=depth,location=(x,-z,y))
    obj=bpy.context.object
    if axis=='z':obj.rotation_euler.x=math.pi/2
    elif axis=='x':obj.rotation_euler.y=math.pi/2
    bpy.ops.object.transform_apply(location=False,rotation=True,scale=True)
    return finish(obj,name,mat,.001)

def begin(name):
    global current
    current=bpy.data.collections.new(name);bpy.context.scene.collection.children.link(current)

def case(upgrade=False):
    shell=charcoal if upgrade else cream;trim=silver if upgrade else edge
    box('Steel shell',(0,.50,0),(.46,1,.82),shell,.018)
    box('Front fascia',(0,.5,.421),(.43,.97,.035),trim,.012)
    for y in [.83,.67]:
        box('Drive recess',(0,y,.444),(.35,.13,.014),dark,.003)
        box('Optical drawer',(0,y+.008,.454),(.326,.096,.012),shell,.003)
        box('Eject key',(.13,y-.026,.465),(.032,.012,.012),trim,.001)
        box('Disc seam',(-.018,y+.036,.463),(.25,.003,.004),dark,.0005)
    cylinder('Power surround',(0,.39,.455),.043,.013,dark)
    cylinder('Power key',(0,.39,.467),.032,.012,trim)
    cylinder('Power indicator',(.074,.39,.467),.008,.013,green,vertices=8)
    for y in [.13+i*.025 for i in range(6)]:
        box('Front intake',(0,y,.455),(.30,.008,.009),dark,.001)
    # Real recessed side vents, rear IO block, PSU and screw heads.
    for row in range(8):
        box('Side ventilation',(.232,.30+row*.031,-.08),(.006,.012,.30),dark,.001)
    box('Rear panel',(0,.50,-.418),(.41,.94,.014),silver,.003)
    box('PSU grille',(0,.81,-.43),(.28,.22,.012),dark,.002)
    for col in range(7):box('PSU slat',(-.12+col*.04,.81,-.44),(.012,.19,.01),shell,.001)
    box('Rear IO',(-.08,.51,-.436),(.13,.25,.012),dark,.001)
    for row in range(4):box('Ports',(-.08,.42+row*.06,-.446),(.07,.025,.01),silver,.001)
    for x in [-.16,.16]:
        for z in [-.28,.28]:box('Foot',(x,.018,z),(.07,.035,.10),dark,.004)

def monitor(lcd=False):
    shell=silver if lcd else cream;trim=charcoal if lcd else edge
    box('Stand base',(0,.032,0),(.75,.064,.44),shell,.022)
    box('Stand neck',(0,.19,-.04),(.18,.28,.16),shell,.018)
    w,h,d=(1.60,1.02,.10) if lcd else (1.58,1.05,.56)
    cy=.84;front=.075 if lcd else .325
    box('Display housing',(0,cy,front-d/2-.02),(w,h,d),shell,.035 if lcd else .065)
    sw,sh=(1.42,.8875) if lcd else (1.28,.8)
    # Real frame opening, with a dark recessed glass surface behind live screen.
    box('Recessed glass',(0,cy,front-.025),(sw+.01,sh+.01,.018),glass,.004)
    t=(w-sw)/2
    for x in [-(sw+t)/2,(sw+t)/2]:box('Side bezel',(x,cy,front-.012),(t,h,.055),shell,.014)
    t=(h-sh)/2
    for y in [cy-(sh+t)/2,cy+(sh+t)/2]:box('Top bottom bezel',(0,y,front-.012),(sw,t,.055),shell,.014)
    cylinder('Power button',(w/2-.12,cy-h/2+.055,front+.02),.022,.015,trim,vertices=12)
    cylinder('Status light',(w/2-.20,cy-h/2+.055,front+.02),.007,.015,green,vertices=8)
    back=front-d-.02
    for x in [-.55+i*.11 for i in range(11)]:box('Rear cooling',(x,cy+.29,back-.006),(.045,.19,.012),dark,.001)
    box('Rear label',(0,cy-.12,back-.012),(.35,.12,.012),trim,.002)

def keyboard(upgrade=False):
    shell=charcoal if upgrade else cream
    box('Keyboard shell',(0,.028,0),(1.25,.056,.48),shell,.015)
    box('Key bed',(0,.059,-.005),(1.20,.012,.42),dark,.003)
    # Geometry is joined before export: individual caps are real faces, not runtime nodes.
    for row in range(6):
        z=-.185+row*.068
        for col in range(20):
            if row==5 and 3<=col<=10:continue
            x=-.575+col*.060
            modifier=(col in [0,1,12,13] or row==0)
            box('Keycap',(x,.078,z),(.052,.028,.052),sage if modifier else edge,.004)
    box('Space bar',(-.185,.078,.155),(.472,.028,.052),edge,.004)
    for x in [.38,.43,.48]:cylinder('Keyboard LED',(x,.069,-.211),.003,.006,green,axis='y',vertices=8)

def mouse(upgrade=False):
    shell=charcoal if upgrade else cream
    bpy.ops.mesh.primitive_uv_sphere_add(segments=20,ring_count=10,location=(0,0,.035))
    obj=bpy.context.object
    for v in obj.data.vertices:
        v.co.x*=.09;v.co.y*=.15;v.co.z=max(-.03,v.co.z*.065)
    finish(obj,'Rounded mouse shell',shell)
    box('Button split',(0,.094,.052),(.003,.004,.16),dark,.001)
    for x in [-.038,.038]:box('Mouse button',(x,.084,.086),(.067,.019,.092),shell,.012)
    cylinder('Scroll wheel',(0,.105,.065),.019,.015,dark,axis='x',vertices=12)
    for x in [-.084,.084]:box('Grip',(x,.04,-.008),(.012,.025,.12),sage if upgrade else shell,.005)

def desk():
    box('Solid oak top',(0,.73,0),(4.8,.10,2.30),oak,.028)
    box('Front edge',(0,.705,1.15),(4.75,.07,.035),oak,.01)
    for x in [-2.15,2.15]:
        for z in [-.91,.91]:box('Desk leg',(x,.34,z),(.13,.68,.13),oak,.012)
    box('Rear rail',(0,.57,-.95),(4.35,.15,.09),oak,.008)

builders={'case_beige':lambda:case(False),'case_charcoal':lambda:case(True),
          'monitor_crt':lambda:monitor(False),'monitor_lcd':lambda:monitor(True),
          'keyboard_beige':lambda:keyboard(False),'keyboard_charcoal':lambda:keyboard(True),
          'mouse_beige':lambda:mouse(False),'mouse_charcoal':lambda:mouse(True),'desk':desk}

for name,build in builders.items():
    begin(name);build()
    # Join by material for a compact imported tree; editable geometry remains in .blend.
    groups={}
    for obj in list(current.objects):groups.setdefault(obj.data.materials[0].name,[]).append(obj)
    for label,objects in groups.items():
        bpy.ops.object.select_all(action='DESELECT')
        for obj in objects:obj.select_set(True)
        bpy.context.view_layer.objects.active=objects[0]
        bpy.ops.object.join();bpy.context.object.name=name+'_'+label.replace(' ','_')
    bpy.ops.object.select_all(action='DESELECT')
    for obj in current.objects:obj.select_set(True)
    bpy.ops.export_scene.gltf(filepath=str(OUTPUT/f'{name}.glb'),export_format='GLB',use_selection=True,export_yup=True,export_apply=True,export_cameras=False,export_lights=False)

for collection in bpy.data.collections:
    if collection.name in builders:collection.hide_viewport=collection.name!='case_beige'
for obj in bpy.data.objects:obj.select_set(False)
for obj in bpy.data.collections['case_beige'].objects:obj.select_set(True)
bpy.context.view_layer.objects.active=next(iter(bpy.data.collections['case_beige'].objects))
for screen in bpy.data.screens:
    for area in screen.areas:
        if area.type=='VIEW_3D':
            area.spaces.active.region_3d.view_distance=2.4
            area.spaces.active.region_3d.view_location=(0,0,.5)
bpy.context.preferences.filepaths.save_version=0
bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE),compress=True)
print('HARDWARE_MODELS_COMPLETE',OUTPUT)
