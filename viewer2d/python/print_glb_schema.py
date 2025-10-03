import sys
import trimesh

def print_glb_schema(glb_path):
    scene = trimesh.load(glb_path, force='scene')
    print(f"[INFO] GLB file: {glb_path}")
    print(f"[INFO] Scene graph nodes:")
    for node_name in scene.graph.nodes:
        node_data = scene.graph[node_name]
        print(f"  Node: {node_name}")
        if hasattr(node_data, 'geometry') and node_data.geometry:
            geom_name = node_data.geometry
            print(f"    Geometry: {geom_name}")
            mesh = scene.geometry.get(geom_name)
            if mesh:
                print(f"      Vertices: {len(mesh.vertices)} | Faces: {len(mesh.faces)}")
                print(f"      Vertex colors: {mesh.visual.vertex_colors.shape if hasattr(mesh.visual, 'vertex_colors') and mesh.visual.vertex_colors is not None else 'None'}")
                print(f"      Metadata: {getattr(mesh, 'metadata', {})}")
        if hasattr(node_data, 'transform'):
            print(f"    Transform: {node_data.transform}")
    print("\n[INFO] Meshes:")
    for mesh_name, mesh in scene.geometry.items():
        print(f"  Mesh: {mesh_name}")
        print(f"    Name: {getattr(mesh, 'name', mesh_name)}")
        print(f"    Vertices: {len(mesh.vertices)}")
        print(f"    Faces: {len(mesh.faces)}")
        # Proprietăți de culoare
        if hasattr(mesh.visual, 'vertex_colors') and mesh.visual.vertex_colors is not None:
            print(f"    Vertex colors: {mesh.visual.vertex_colors.shape}")
            if mesh.visual.vertex_colors.shape[0] > 0:
                print(f"    First vertex color: {mesh.visual.vertex_colors[0]}")
        else:
            print(f"    Vertex colors: None")
        # Material PBR
        mat = getattr(mesh.visual, 'material', None)
        if mat:
            base_color = getattr(mat, 'baseColorFactor', None)
            alpha_mode = getattr(mat, 'alphaMode', None)
            print(f"    baseColorFactor: {base_color}")
            print(f"    alphaMode: {alpha_mode}")
        print(f"    Metadata: {getattr(mesh, 'metadata', {})}")

if __name__ == "__main__":
    # Hardcodează calea către fișierul GLB aici:
    glb_path = r"C:/Users/ionut.ciuntuc/Documents/viewer2d/python/dxf/etaj_01.glb"
    print_glb_schema(glb_path)
