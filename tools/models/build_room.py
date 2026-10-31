"""Rebuild complete room GLBs, offline authoring only. Python 3 + Pillow.
Godot coordinates: metres, Y up, furniture origin at floor centre.
Meshes are combined by material; nothing is generated at game runtime.
"""
import json, struct, math, random, io
from pathlib import Path
from PIL import Image
OUT = Path(__file__).resolve().parents[2] / 'assets/models/room'
OUT.mkdir(parents=True, exist_ok=True)
COLORS = {'oak':(.40,.24,.12),'edge':(.23,.14,.08),'wall':(.66,.69,.57),
 'floor':(.57,.40,.24),'trim':(.79,.74,.58),'sage':(.22,.36,.30),
 'dark':(.065,.10,.10),'metal':(.16,.21,.20),'glass':(.26,.52,.57),
 'sky':(.50,.71,.69),'cream':(.80,.73,.53),'blue':(.17,.32,.40),
 'red':(.52,.24,.18),'green':(.19,.37,.20),'leaf':(.36,.52,.25),
 'rug':(.25,.40,.36),'gold':(.70,.52,.23)}
class Model:
 def __init__(self): self.groups={}
 def box(self,name,center,size,mat):
  x,y,z=center; w,h,d=[v/2 for v in size]
  # CCW triangles viewed from the outside.
  faces=[((1,0,0),[(w,-h,d),(w,-h,-d),(w,h,-d),(w,h,d)]),
   ((-1,0,0),[(-w,-h,-d),(-w,-h,d),(-w,h,d),(-w,h,-d)]),
   ((0,1,0),[(-w,h,d),(w,h,d),(w,h,-d),(-w,h,-d)]),
   ((0,-1,0),[(-w,-h,-d),(w,-h,-d),(w,-h,d),(-w,-h,d)]),
   ((0,0,1),[(-w,-h,d),(w,-h,d),(w,h,d),(-w,h,d)]),
   ((0,0,-1),[(w,-h,-d),(-w,-h,-d),(-w,h,-d),(w,h,-d)])]
  verts=self.groups.setdefault((name,mat),[])
  for n,pts in faces:
   for i in [0,1,2,0,2,3]:
    p=pts[i];uv=[(0,1),(1,1),(1,0),(0,0)][i]
    verts.append((*[p[j]+center[j] for j in range(3)],*n,*uv))
 def save(self,name):
  data=bytearray();views=[];access=[];meshes=[];nodes=[]
  def view(raw,target=None):
   while len(data)%4:data.append(0)
   idx=len(views); v={'buffer':0,'byteOffset':len(data),'byteLength':len(raw)}
   if target:v['target']=target
   views.append(v);data.extend(raw);return idx
  def attr(rows,kind):
   v=view(struct.pack('<'+'f'*sum(map(len,rows)),*[n for row in rows for n in row]),34962)
   a={'bufferView':v,'componentType':5126,'count':len(rows),'type':kind}
   if kind=='VEC3':a.update(min=[min(r[j] for r in rows) for j in range(3)],max=[max(r[j] for r in rows) for j in range(3)])
   access.append(a);return len(access)-1
  mats=[];keys=list(COLORS)
  # Deterministic nearest-filtered wood pixels, embedded in every model using oak/floor.
  rng=random.Random(18); im=Image.new('RGB',(64,64))
  for y in range(64):
   for x in range(64):
    grain=(y//4)%4*.025+rng.choice([-.018,0,.018]);seam=(y%16==0 or (x%32==((y//16)%2)*16))
    im.putpixel((x,y),tuple(int(max(0,min(1,c+grain-(.09 if seam else 0)))*255) for c in (.60,.43,.27)))
  png=io.BytesIO();im.save(png,format='PNG');iv=view(png.getvalue())
  for k in keys:
   pbr={'baseColorFactor':[*COLORS[k],1],'metallicFactor':0,'roughnessFactor':.85}
   if k in ['oak','floor']:
    pbr['baseColorFactor']=[1,1,1,1];pbr['baseColorTexture']={'index':0}
   mats.append({'name':k,'pbrMetallicRoughness':pbr})
  for (label,mat),verts in self.groups.items():
   attrs={'POSITION':attr([v[:3] for v in verts],'VEC3'),'NORMAL':attr([v[3:6] for v in verts],'VEC3'),'TEXCOORD_0':attr([v[6:] for v in verts],'VEC2')}
   meshes.append({'name':label,'primitives':[{'attributes':attrs,'material':keys.index(mat)}]})
   nodes.append({'name':label,'mesh':len(meshes)-1})
  doc={'asset':{'version':'2.0','generator':'GameMemoirStore room authoring'},'scene':0,'scenes':[{'nodes':list(range(len(nodes)))}],'nodes':nodes,'meshes':meshes,'materials':mats,'accessors':access,'bufferViews':views,'buffers':[{'byteLength':len(data)}], 'images':[{'bufferView':iv,'mimeType':'image/png'}],'samplers':[{'magFilter':9728,'minFilter':9728,'wrapS':10497,'wrapT':10497}],'textures':[{'source':0,'sampler':0}]}
  raw=json.dumps(doc,separators=(',',':')).encode();raw+=b' '*((-len(raw))%4);data+=b'\0'*((-len(data))%4)
  glb=struct.pack('<III',0x46546c67,2,12+8+len(raw)+8+len(data))+struct.pack('<II',len(raw),0x4e4f534a)+raw+struct.pack('<II',len(data),0x004e4942)+data
  (OUT/f'{name}.glb').write_bytes(glb)

m=Model();m.box('Floor',(0,-.10,0),(8.24,.2,6.24),'floor')
m.box('Left_Wall',(-4.06,1.6,0),(.12,3.2,6.24),'wall')
m.box('Back_Wall',(0,1.6,-3.06),(8.24,3.2,.12),'wall')
m.box('Left_Skirting',(-3.97,.11,0),(.08,.22,6),'trim')
m.box('Back_Skirting',(0,.11,-2.97),(8,.22,.08),'trim')
# Window is a complete part of the room shell, with pixel skyline and frame.
m.box('Left_Window',(-3.98,2,-.8),(.08,1.45,2.3),'glass')
for z in [-1.99,.39,-.8]:m.box('Left_Frame',(-3.87,2,z),(.16,1.6,.07),'cream')
for y in [1.22,2.78,2.0]:m.box('Left_Frame',(-3.87,y,-.8),(.16,.07,2.45),'cream')
for z,h in [(-1.7,.35),(-1.35,.6),(-1,.42),(-.55,.75),(-.15,.55),(.1,.3)]:m.box('Left_Skyline',(-3.9,1.27+h/2,z),(.025,h,.25),'sky')
m.box('Back_PictureFrame',(1.8,2.16,-2.94),(1.65,1.1,.08),'edge')
m.box('Back_Picture',(1.8,2.16,-2.89),(1.49,.94,.03),'blue')
for x,y,w,h in [(1.4,2.2,.45,.2),(1.8,2.05,.55,.18),(2.2,2.35,.26,.22)]:m.box('Back_PixelArt',(x,y,-2.865),(w,h,.02),'sage')
m.box('Back_PixelSun',(2.2,2.4,-2.84),(.18,.18,.025),'gold');m.save('room_shell')

# The detailed chair is generated by build_hardware.py and remains editable in hardware.blend.
m=Model();m.box('Back',(0,1.23,-.21),(1.35,2.46,.06),'edge')
for x in [-.68,.68]:m.box('Sides',(x,1.25,0),(.10,2.5,.52),'oak')
for y in [.08,.68,1.28,1.88,2.52]:m.box('Shelves',(0,y,0),(1.46,.09,.58),'oak')
for row in range(3):
 for i in range(7-row):
  height=.30+(i%3)*.07
  m.box('Books'+str(i%3),(-.53+i*.16,.73+row*.6+height/2,.02),(.11,height,.32),['blue','red','cream'][i%3])
m.save('bookcase')
m=Model();m.box('Base',(0,.045,0),(.48,.09,.48),'metal');m.box('Stem',(0,.95,0),(.05,1.85,.05),'gold')
m.box('Shade',(0,1.86,0),(.64,.4,.64),'cream');m.box('WarmLight',(0,1.66,0),(.49,.02,.49),'gold');m.save('lamp')
m=Model();m.box('Rug',(0,.012,0),(3.6,.024,2.2),'rug')
for z in [-.96,.96]:m.box('Border',(0,.026,z),(3.35,.006,.06),'cream')
for x in [-1.6,1.6]:m.box('Border',(x,.026,0),(.06,.006,1.98),'cream')
for x in [-1.0,-.5,0,.5,1.0]:m.box('Pattern',(x,.027,0),(.06,.006,.8),'sage')
m.save('rug')
m=Model();m.box('Pot',(0,.24,0),(.5,.48,.5),'red');m.box('Soil',(0,.49,0),(.43,.025,.43),'edge')
for x,y,z,s in [(0,.95,0,.36),(-.25,.76,0,.30),(.23,1.1,.02,.35),(0,1.3,0,.30),(.05,.81,.25,.30)]:
 m.box('Stem',(x/2,y/2+.24,z/2),(.035,y-.48,.035),'green');m.box('Leaves',(x,y,z),(s,s*.75,s*.8),'leaf')
m.save('plant')
print('ROOM_MODELS_COMPLETE',OUT)
