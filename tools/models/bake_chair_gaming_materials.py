"""Embed portable PBR material maps into the already UV-unwrapped gaming chair GLB.
Requires Pillow. Usage: python tools/models/bake_chair_gaming_materials.py --output /tmp/chair.glb
Use --in-place ONLY after inspecting the preview in Blender.
"""
import argparse, io, json, math, struct
from pathlib import Path
from PIL import Image

ROOT=Path(__file__).resolve().parents[2]
SOURCE=ROOT/"assets/models/room/seating/chair_gaming.glb"
# Offline PBR presets: the retired runtime material library is not a dependency.
PRESETS={
    "plastic": (0.0, 0.82, 0.07),
    "metal": (0.68, 0.53, 0.10),
    "rubber": (0.0, 0.92, 0.05),
    "fabric": (0.0, 0.94, 0.17),
    "leather": (0.0, 0.88, 0.12),
}
PARTS={
"graphite":("plastic/plastic_black","343b44"),
"gunmetal":("metal/metal_black_matte","59616b"),
"rubber":("rubber/rubber_black","24282c"),
"wheel_hub":("metal/metal_brushed_steel","444c55"),
"steel":("metal/metal_brushed_steel","646b73"),
"dark_shell":("plastic/plastic_black","343b44"),
"grey_inset":("fabric/fabric_gray","7d8288"),
"leather_pearl":("leather/leather_white","d0c9bd"),
"leather_cream":("leather/leather_white","ded5c7"),
"stitch":("fabric/fabric_beige","a79c8c"),
"edge_welt":("leather/leather_black","666c72"),
"leather_shadow":("leather/leather_white","aea79d")}
PATTERNS={"leather","fabric","metal","wood"}

def parse(data):
    if data[:4]!=b"glTF" or struct.unpack_from("<I",data,4)[0]!=2 or struct.unpack_from("<I",data,8)[0]!=len(data):
        raise ValueError("Invalid glTF 2.0 GLB")
    off=12;chunks=[]
    while off<len(data):
        size,kind=struct.unpack_from("<I4s",data,off);off+=8
        chunks.append((kind,data[off:off+size]));off+=size
    if len(chunks)!=2 or chunks[0][0]!=b"JSON" or chunks[1][0]!=b"BIN\x00":
        raise ValueError("Expected single embedded JSON and BIN")
    return json.loads(chunks[0][1]),chunks[1][1]

def pack(meta,buf):
    j=json.dumps(meta,separators=(",",":"),ensure_ascii=False).encode("utf-8")
    j+=b" "*((-len(j))%4)
    buf+=b"\x00"*((-len(buf))%4)
    return b"glTF"+struct.pack("<II",2,28+len(j)+len(buf))+struct.pack("<I4s",len(j),b"JSON")+j+struct.pack("<I4s",len(buf),b"BIN\x00")+buf

def preset(p):
    family=p.split("/")[0]
    if family not in PRESETS:
        raise ValueError("Unsupported material family: "+family)
    return PRESETS[family]

def png(im):
    b=io.BytesIO();im.save(b,format="PNG",optimize=True);return b.getvalue()

def maps(family):
    """Generate deterministic, seamless 64px microdetail without external assets."""
    if family not in PATTERNS:
        raise ValueError("Unsupported texture family: "+family)
    w=h=64
    im=Image.new("L",(w,h))
    raw=[]
    for y in range(h):
        for x in range(w):
            grain=((x*37+y*61+(x*y)%31)%19)-9
            if family=="metal":
                detail=((y%8)-4)*2+grain//4
            elif family=="fabric":
                detail=(5 if x%4==0 else -3)+(5 if y%4==0 else -3)+grain//3
            elif family=="leather":
                detail=grain//2+(2 if (x//5+y//7)%2==0 else -2)
            else:
                detail=grain//2+(5 if y%8==0 else -2)
            raw.append(max(215,min(250,236+detail)))
    im.putdata(raw)
    def at(x,y):return raw[(y%h)*w+x%w]
    mr=Image.new("RGB",(w,h))
    normal=Image.new("RGB",(w,h))
    mpx=[];npx=[]
    for y in range(h):
        for x in range(w):
            variation=max(0,min(255,245+(at(x,y)-236)//3))
            # glTF G channel carries roughness; B channel metallic.
            mpx.append((255,variation,255))
            dx=(at(x+1,y)-at(x-1,y))/255*.9
            dy=(at(x,y+1)-at(x,y-1))/255*.9
            length=math.sqrt(dx*dx+dy*dy+1)
            npx.append(tuple(round((v*.5+.5)*255) for v in (-dx/length,-dy/length,1/length)))
    mr.putdata(mpx);normal.putdata(npx)
    return {"albedo":png(im.convert("RGB")),"roughness":png(mr),"normal":png(normal)}

def bake(source,target):
    gltf,binary=parse(Path(source).read_bytes())
    # Once finalized, rebuilding the GLB must be idempotent.
    names = {m.get("name") for m in gltf.get("materials", [])}
    if set(PARTS).issubset(names):
        if len(gltf.get("images", [])) < 9:
            raise ValueError("Chair materials exist but embedded PBR images are missing")
        target=Path(target)
        target.parent.mkdir(parents=True,exist_ok=True)
        if Path(source).resolve() != target.resolve():
            target.write_bytes(Path(source).read_bytes())
        return {"parts":len(PARTS),"embedded_textures":len(gltf["images"]),"bytes":len(Path(source).read_bytes())}
    buf=bytearray(binary)
    views=gltf.setdefault("bufferViews",[])
    images=gltf.setdefault("images",[])
    textures=gltf.setdefault("textures",[])
    samplers=gltf.setdefault("samplers",[])
    materials=gltf.setdefault("materials",[])
    mesh_list=gltf["meshes"]
    sampler=len(samplers)
    samplers.append({"magFilter":9729,"minFilter":9987,"wrapS":10497,"wrapT":10497})
    cache={}
    def add_texture(blob,name):
        buf.extend(b"\x00"*((-len(buf))%4))
        pos=len(buf);buf.extend(blob)
        view=len(views);views.append({"buffer":0,"byteOffset":pos,"byteLength":len(blob)})
        image=len(images);images.append({"name":name,"bufferView":view,"mimeType":"image/png"})
        idx=len(textures);textures.append({"name":name,"sampler":sampler,"source":image})
        return idx
    def get(family,kind):
        if family not in cache:
            cache[family]={k:add_texture(blob,family+"_"+k) for k,blob in maps(family).items()}
        return cache[family][kind]
    found=set()
    for node in gltf["nodes"]:
        name=node.get("name")
        if name not in PARTS:continue
        if "mesh" not in node:raise ValueError("Missing chair mesh: "+name)
        preset_name,color=PARTS[name]
        family=preset_name.split("/")[0]
        metallic,roughness,normal_scale=preset(preset_name)
        rgb=[int(color[i:i+2],16)/255 for i in (0,2,4)]
        material={"name":name,"pbrMetallicRoughness":{"baseColorFactor":rgb+[1.0],"metallicFactor":metallic,"roughnessFactor":roughness}}
        if family in PATTERNS:
            material["pbrMetallicRoughness"]["baseColorTexture"]={"index":get(family,"albedo")}
            material["pbrMetallicRoughness"]["metallicRoughnessTexture"]={"index":get(family,"roughness")}
            material["normalTexture"]={"index":get(family,"normal"),"scale":normal_scale}
        idx=len(materials);materials.append(material)
        for prim in mesh_list[node["mesh"]]["primitives"]:
            if not {"NORMAL","TEXCOORD_0"}.issubset(prim["attributes"]):
                raise ValueError("Missing UV/normals: "+name)
            prim["material"]=idx
        found.add(name)
    if found!=set(PARTS):raise ValueError("Chair mesh names changed: "+repr(set(PARTS)-found))
    gltf["buffers"][0]["byteLength"]=len(buf)
    output=pack(gltf,bytes(buf))
    parse(output)
    target=Path(target);target.parent.mkdir(parents=True,exist_ok=True);target.write_bytes(output)
    return {"parts":len(found),"embedded_textures":sum(map(len,cache.values())),"bytes":len(output)}

def main():
    p=argparse.ArgumentParser()
    p.add_argument("--source",type=Path,default=SOURCE)
    p.add_argument("--output",type=Path)
    p.add_argument("--in-place",action="store_true")
    args=p.parse_args()
    if args.in_place==(args.output is not None):
        p.error("choose exactly one of --output or --in-place")
    target=args.source if args.in_place else args.output
    print(json.dumps(bake(args.source,target),indent=2))
if __name__=="__main__":main()
