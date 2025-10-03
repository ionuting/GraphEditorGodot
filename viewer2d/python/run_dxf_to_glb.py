import os
from dxf_to_glb_trimesh import dxf_to_gltf

def main():
    # Hardcodează calea către fișierul DXF și către fișierul GLB rezultat
    dxf_path = r"C:/Users/ionut.ciuntuc/Documents/viewer2d/python/dxf/etaj_01.dxf"
    glb_path = r"C:/Users/ionut.ciuntuc/Documents/viewer2d/python/dxf/etaj_01_out.glb"

    print(f"[INFO] Conversie DXF → GLB: {dxf_path} -> {glb_path}")
    dxf_to_gltf(dxf_path, glb_path)
    print(f"[INFO] Conversie finalizată: {glb_path}")

if __name__ == "__main__":
    main()
