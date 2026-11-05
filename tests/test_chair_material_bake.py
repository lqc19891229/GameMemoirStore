"""Material baker regression tests; requires Pillow."""
import sys,tempfile,unittest
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/"tools/models"))
import bake_chair_gaming_materials as baker

class TestGLBMaterials(unittest.TestCase):
    def test_pack_parse(self):
        metadata={"asset":{"version":"2.0"},"buffers":[{"byteLength":4}]}
        doc,buf=baker.parse(baker.pack(metadata,b"\x01\x02\x03\x04"))
        self.assertEqual(doc["asset"]["version"],"2.0")
        self.assertEqual(buf,b"\x01\x02\x03\x04")
    def test_maps(self):
        for family in baker.PATTERNS:
            for b in baker.maps(family).values():
                self.assertTrue(b.startswith(b"\x89PNG"))
    def test_full_chair_bake(self):
        with tempfile.TemporaryDirectory() as d:
            output=Path(d)/"chair.glb"
            info=baker.bake(baker.SOURCE,output)
            self.assertEqual(info["parts"],12)
            self.assertEqual(info["embedded_textures"],9)
            gltf,_=baker.parse(output.read_bytes())
            self.assertEqual(len(gltf["images"]),9)
            for node in gltf["nodes"]:
                if node.get("name") in baker.PARTS:
                    for primitive in gltf["meshes"][node["mesh"]]["primitives"]:
                        mat=gltf["materials"][primitive["material"]]
                        self.assertIn("baseColorFactor",mat["pbrMetallicRoughness"])
if __name__=="__main__":unittest.main()
