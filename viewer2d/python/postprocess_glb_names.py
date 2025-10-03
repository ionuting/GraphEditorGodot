import sys
from pygltflib import GLTF2

def rename_nodes(glb_path, out_path=None):
    gltf = GLTF2().load(glb_path)
    for node in gltf.nodes:
        # Dacă numele e implicit (solid_0 etc), îl păstrăm sau îl poți schimba după preferință
        if node.name:
            # Exemplu: nu schimba dacă deja e LayerName_index_uuid
            continue
        # Poți adăuga logică suplimentară aici pentru a seta nume custom
    # Salvează cu același nume sau ca out_path
    out_path = out_path or glb_path
    gltf.save(out_path)
    print(f"[DEBUG] GLB node names updated: {out_path}")

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python postprocess_glb_names.py input.glb [output.glb]")
        sys.exit(1)
    glb_path = sys.argv[1]
    out_path = sys.argv[2] if len(sys.argv) > 2 else None
    rename_nodes(glb_path, out_path)
