import ezdxf
import trimesh
import numpy as np
from trimesh.creation import extrude_polygon
from shapely.geometry import Polygon
import uuid
import sys
import time
import csv
import ast
import os
from trimesh.exchange import gltf

# -----------------------------
# Materiale din CSV
# -----------------------------
def load_layer_materials(csv_path):
    materials = {}
    if not os.path.exists(csv_path):
        return materials
    with open(csv_path, newline='', encoding='utf-8') as csvfile:
        reader = csv.DictReader(csvfile)
        for row in reader:
            color = ast.literal_eval(row['color'])
            alpha = float(row['alpha'])
            materials[row['layer']] = color + [alpha]
    return materials

LAYER_MATERIALS = load_layer_materials(
    os.path.join(os.path.dirname(__file__), "../layer_materials.csv")
)

def get_material(layer):
    if layer in LAYER_MATERIALS:
        return LAYER_MATERIALS[layer]
    return LAYER_MATERIALS.get("default", [0.5, 1.0, 0.0, 1.0])

# -----------------------------
# Funcții pentru arce
# -----------------------------
def discretize_arc(start, end, bulge, segments=16):
    """
    Convertește un arc definit prin bulge în puncte discrete.
    
    Args:
        start: (x, y) punct de start
        end: (x, y) punct de final
        bulge: valoarea bulge din DXF
        segments: numărul de segmente pentru arc
    
    Returns:
        Lista de puncte (x, y) care aproximează arcul
    """
    if abs(bulge) < 1e-6:
        return [start, end]
    
    # Calculează parametrii cercului
    start = np.array(start)
    end = np.array(end)
    
    chord = end - start
    chord_length = np.linalg.norm(chord)
    
    if chord_length < 1e-6:
        return [start]
    
    # Unghi total al arcului
    angle = 4 * np.arctan(bulge)
    
    # Raza cercului
    radius = chord_length * (1 + bulge**2) / (4 * abs(bulge))
    
    # Centrul cercului
    sagitta = bulge * chord_length / 2
    chord_mid = (start + end) / 2
    chord_dir = chord / chord_length
    perp = np.array([-chord_dir[1], chord_dir[0]])
    center = chord_mid + perp * (radius - abs(sagitta)) * np.sign(bulge)
    
    # Unghiuri de start și end
    start_angle = np.arctan2(start[1] - center[1], start[0] - center[0])
    
    # Generează puncte pe arc
    points = []
    for i in range(segments + 1):
        t = i / segments
        current_angle = start_angle + angle * t
        point = center + radius * np.array([np.cos(current_angle), np.sin(current_angle)])
        points.append(tuple(point))
    
    return points[:-1]  # Excludem ultimul punct pentru a evita duplicarea

def lwpolyline_to_points(entity, arc_segments=16):
    """
    Convertește LWPOLYLINE în listă de puncte, discretizând arcele.
    
    Args:
        entity: entitatea LWPOLYLINE din ezdxf
        arc_segments: număr de segmente pentru fiecare arc
    
    Returns:
        Lista de puncte (x, y)
    """
    points = []
    lwpoints = list(entity.lwpoints)
    
    for i in range(len(lwpoints)):
        x, y, start_width, end_width, bulge = lwpoints[i]
        start_point = (float(x), float(y))
        
        if i < len(lwpoints) - 1:
            next_x, next_y = lwpoints[i + 1][:2]
            end_point = (float(next_x), float(next_y))
        elif entity.closed:
            next_x, next_y = lwpoints[0][:2]
            end_point = (float(next_x), float(next_y))
        else:
            points.append(start_point)
            break
        
        if abs(bulge) > 1e-6:
            # Arc prezent
            arc_points = discretize_arc(start_point, end_point, bulge, arc_segments)
            points.extend(arc_points)
        else:
            # Segment drept
            points.append(start_point)
    
    return points

def polyline_to_points(entity, arc_segments=16):
    """
    Convertește POLYLINE în listă de puncte, discretizând arcele.
    
    Args:
        entity: entitatea POLYLINE din ezdxf
        arc_segments: număr de segmente pentru fiecare arc
    
    Returns:
        Lista de puncte (x, y)
    """
    points = []
    vertices = list(entity.vertices)
    
    for i in range(len(vertices)):
        vertex = vertices[i]
        start_point = (float(vertex.dxf.location.x), float(vertex.dxf.location.y))
        bulge = getattr(vertex.dxf, 'bulge', 0.0)
        
        if i < len(vertices) - 1:
            next_vertex = vertices[i + 1]
            end_point = (float(next_vertex.dxf.location.x), float(next_vertex.dxf.location.y))
        elif entity.is_closed:
            next_vertex = vertices[0]
            end_point = (float(next_vertex.dxf.location.x), float(next_vertex.dxf.location.y))
        else:
            points.append(start_point)
            break
        
        if abs(bulge) > 1e-6:
            # Arc prezent
            arc_points = discretize_arc(start_point, end_point, bulge, arc_segments)
            points.extend(arc_points)
        else:
            # Segment drept
            points.append(start_point)
    
    return points

# -----------------------------
# Export doar GLB
# -----------------------------
def export_scene(scene, out_path):
    if not out_path.lower().endswith(".glb"):
        out_path = os.path.splitext(out_path)[0] + ".glb"

    glb_bytes = gltf.export_glb(scene)
    with open(out_path, "wb") as f:
        f.write(glb_bytes)

    print(f"[DEBUG] Exported GLB: {out_path}")

# -----------------------------
# Conversie DXF → GLB
# -----------------------------
def dxf_to_gltf(dxf_path, out_path, arc_segments=16):
    print(f"[DEBUG] Start DXF to GLB: {dxf_path} -> {out_path}")
    start_time = time.time()

    doc = ezdxf.readfile(dxf_path)
    msp = doc.modelspace()

    solids = []
    voids = []
    mesh_name_count = {}
    mapping = []

    for idx, e in enumerate(msp):
        ent_type = e.dxftype()
        handle = getattr(e.dxf, "handle", None)
        layer = getattr(e.dxf, "layer", "default")
        xdata = {}

        if e.has_xdata:
            appids = []
            if hasattr(e, "get_xdata_appids"):
                appids = e.get_xdata_appids()
            if "QCAD" not in appids:
                appids.append("QCAD")
            for appid in appids:
                try:
                    data = e.get_xdata(appid)
                    if data:
                        xdata[appid] = list(data)
                        print(f"[DEBUG] XDATA for {ent_type} handle={handle} appid={appid}: {xdata[appid]}")
                except Exception as ex:
                    print(f"[DEBUG] XDATA error for appid {appid}: {ex}")

        # Debug pentru toate entitățile, nu doar cele cu XDATA
        print(f"[DEBUG] Processing entity: {ent_type} handle={handle} layer={layer}")

        def parse_xdata_from_list(xdata_list):
            height, z = 1.0, 0.0
            name_str = ""
            solid_flag = 1  # Implicit solid, doar dacă e explicit setat pe 0 devine void
            for code, value in xdata_list:
                if code == 1000:
                    sval = str(value)
                    if sval.startswith("height:"):
                        try:
                            height = float(sval.split(":")[1])
                        except Exception:
                            pass
                    elif sval.startswith("z:"):
                        try:
                            z = float(sval.split(":")[1])
                        except Exception:
                            pass
                    elif sval.startswith("Name:"):
                        name_str = sval.split(":", 1)[1].strip()
                    elif sval.startswith("solid:"):
                        try:
                            solid_flag = int(sval.split(":")[1])
                        except Exception:
                            pass
            return height, z, name_str, solid_flag

        height, z, name_str, solid_flag = parse_xdata_from_list(xdata.get("QCAD", []))
        rgba = get_material(layer)
        color, alpha = rgba[:3], rgba[3]
        mesh, mesh_uuid = None, str(uuid.uuid4())

        key = (layer, name_str)
        mesh_name_count[key] = mesh_name_count.get(key, 0) + 1
        mesh_name = f"{layer}_{name_str}_{mesh_name_count[key]}" if name_str else f"{layer}_{mesh_name_count[key]}"
        
        # Determină rolul elementului: void dacă solid_flag=0, altfel solid
        is_void = (solid_flag == 0)

        poly = None
        points = []
        closed = False
        
        # Procesare LWPOLYLINE cu suport pentru arce
        if ent_type == "LWPOLYLINE":
            points = lwpolyline_to_points(e, arc_segments)
            closed = getattr(e, "closed", False)
            if closed and len(points) >= 3:
                poly = Polygon(points)
                if poly.is_valid and poly.area > 0:
                    mesh = extrude_polygon(poly, height)
                    mesh.apply_translation([0, 0, z])

        # Procesare POLYLINE cu suport pentru arce
        elif ent_type == "POLYLINE":
            points = polyline_to_points(e, arc_segments)
            closed = getattr(e, "is_closed", False)
            if closed and len(points) >= 3:
                poly = Polygon(points)
                if poly.is_valid and poly.area > 0:
                    mesh = extrude_polygon(poly, height)
                    mesh.apply_translation([0, 0, z])

        # Procesare CIRCLE
        elif ent_type == "CIRCLE" and hasattr(e, "dxf"):
            center = (e.dxf.center.x, e.dxf.center.y)
            radius = e.dxf.radius
            segments = max(32, arc_segments * 2)  # Mai multe segmente pentru cercuri
            points = [
                (
                    center[0] + np.cos(2 * np.pi * i / segments) * radius,
                    center[1] + np.sin(2 * np.pi * i / segments) * radius,
                )
                for i in range(segments)
            ]
            closed = True
            poly = Polygon(points)
            if poly.is_valid and poly.area > 0:
                mesh = extrude_polygon(poly, height)
                mesh.apply_translation([0, 0, z])

        # Calculează proprietăți geometrice pentru mapping
        if closed and len(points) >= 3:
            segment_lengths = [np.linalg.norm(np.array(points[i]) - np.array(points[(i+1)%len(points)])) for i in range(len(points))]
            perimeter = float(np.sum(segment_lengths))
            area = float(poly.area) if poly else 0.0
            lateral_area = perimeter * height
            volume = area * height
        else:
            segment_lengths = []
            perimeter = 0.0
            area = 0.0
            lateral_area = 0.0
            volume = 0.0

        if mesh is not None:
            mesh.name = mesh_name

            mesh.metadata = {
                "uuid": mesh_uuid,
                "handle": handle,
                "layer": layer,
                "name": mesh_name,
                "color": color,
                "alpha": alpha,
                "solid_flag": solid_flag,
                "is_void": is_void,
            }

            rgba_float = np.array(color + [alpha], dtype=np.float32)
            mesh.visual.vertex_colors = np.tile(rgba_float, (len(mesh.vertices), 1))
            mesh.visual.material = trimesh.visual.material.PBRMaterial(
                baseColorFactor=[1.0, 1.0, 1.0, alpha],
                vertex_color=True,
                alphaMode="BLEND" if alpha < 1.0 else "OPAQUE"
            )

            print(f"[DEBUG] Export mesh: {mesh_name} | color={color} alpha={alpha} | vertex_colors.shape={mesh.visual.vertex_colors.shape if hasattr(mesh.visual, 'vertex_colors') else 'N/A'} | height={height} z={z}")

            entry = {
                "dxf_handle": handle,
                "mesh_name": mesh_name,
                "uuid": mesh_uuid,
                "role": -1 if is_void else 1,
                "solid_flag": solid_flag,
                "layer": layer,
                "segment_lengths": segment_lengths,
                "perimeter": perimeter,
                "area": area,
                "lateral_area": lateral_area,
                "volume": volume,
                "vertices": [list(map(float, pt)) for pt in points] if points else [],
                "is_cut_by": []
            }
            mapping.append(entry)

            if is_void:
                voids.append(mesh)
            else:
                solids.append(mesh)

    uuid_to_entry = {entry["uuid"]: entry for entry in mapping}

    # Grupează meshurile pe layere pentru aplicarea logicii de void per layer
    meshes_by_layer = {}
    for mesh in solids + voids:
        layer = mesh.metadata.get("layer", "default")
        if layer not in meshes_by_layer:
            meshes_by_layer[layer] = {"solids": [], "voids": []}
        
        if mesh.metadata.get("is_void", False):
            meshes_by_layer[layer]["voids"].append(mesh)
        else:
            meshes_by_layer[layer]["solids"].append(mesh)

    # Aplică void-uri per layer (voidurile taie doar solidele din același layer)
    new_solids = []
    
    for layer, layer_meshes in meshes_by_layer.items():
        layer_solids = layer_meshes["solids"]
        layer_voids = layer_meshes["voids"]
        
        print(f"[DEBUG] Layer '{layer}': {len(layer_solids)} solids, {len(layer_voids)} voids")
        
        if layer_voids:
            # Creează union din toate voidurile de pe acest layer
            layer_void_union = trimesh.util.concatenate(layer_voids)
            
            for mesh in layer_solids:
                solid_uuid = mesh.metadata.get("uuid")
                cutting_voids = []
                
                # Verifică care voiduri din același layer taie acest solid
                for void_mesh in layer_voids:
                    void_uuid = void_mesh.metadata.get("uuid")
                    try:
                        # Verificare simplă prin intersecția bounding box-urilor
                        bb_intersect = not (
                            mesh.bounds[1][0] < void_mesh.bounds[0][0] or
                            mesh.bounds[0][0] > void_mesh.bounds[1][0] or
                            mesh.bounds[1][1] < void_mesh.bounds[0][1] or
                            mesh.bounds[0][1] > void_mesh.bounds[1][1] or
                            mesh.bounds[1][2] < void_mesh.bounds[0][2] or
                            mesh.bounds[0][2] > void_mesh.bounds[1][2]
                        )
                        
                        if bb_intersect:
                            try:
                                intersection = mesh.intersection(void_mesh)
                                if intersection and hasattr(intersection, 'volume') and intersection.volume > 1e-6:
                                    cutting_voids.append(void_uuid)
                                    print(f"[DEBUG] Void {void_uuid} (layer {layer}) cuts solid {solid_uuid} (layer {layer})")
                            except Exception as ex:
                                print(f"[DEBUG] Intersection test failed: {ex}")
                    except Exception as ex:
                        print(f"[DEBUG] Bounds check failed: {ex}")
                
                # Actualizează mapping-ul cu voidurile care taie acest solid
                if solid_uuid in uuid_to_entry:
                    uuid_to_entry[solid_uuid]["is_cut_by"] = cutting_voids
                
                # Aplică operația de diferență booleană
                try:
                    diff = mesh.difference(layer_void_union)
                    if diff:
                        if isinstance(diff, list):
                            for dmesh in diff:
                                dmesh.metadata = dict(mesh.metadata) if hasattr(mesh, 'metadata') else {}
                                new_solids.append(dmesh)
                        else:
                            diff.metadata = dict(mesh.metadata) if hasattr(mesh, 'metadata') else {}
                            new_solids.append(diff)
                    else:
                        new_solids.append(mesh)
                except Exception as ex:
                    print(f"[DEBUG] Boolean difference failed for mesh {solid_uuid}: {ex}")
                    new_solids.append(mesh)
        else:
            # Nu există voiduri pe acest layer, adaugă toate solidele nemodificate
            new_solids.extend(layer_solids)
    
    solids = new_solids

    # Creează scenă și exportă
    scene = trimesh.Scene()
    for i, mesh in enumerate(solids):
        if "name" in mesh.metadata:
            node_name = mesh.metadata["name"]
        else:
            node_name = f"solid_{i}"
            print(f"[WARNING] Mesh fără 'name' în metadata, fallback la {node_name}")
        print(f"[DEBUG] Add to scene: node_name={node_name} | mesh={mesh}")
        scene.add_geometry(mesh, node_name=node_name)

    # Export mapping JSON
    json_path = os.path.splitext(out_path)[0] + "_mapping.json"
    import json
    with open(json_path, "w", encoding="utf-8") as jf:
        json.dump(mapping, jf, indent=2)
    print(f"[DEBUG] Exported mapping JSON: {json_path}")

    export_scene(scene, out_path)

    elapsed = time.time() - start_time
    print(f"[DEBUG] Finished DXF to GLB in {elapsed:.2f} sec.")

# -----------------------------
# Main
# -----------------------------
if __name__ == "__main__":
    if len(sys.argv) < 3:
        print("Usage: python dxf_to_glb.py input.dxf output.glb [arc_segments]")
        sys.exit(1)

    dxf_path = sys.argv[1]
    out_path = sys.argv[2]
    arc_segments = int(sys.argv[3]) if len(sys.argv) > 3 else 16

    dxf_to_gltf(dxf_path, out_path, arc_segments)

    print(f"Converted {dxf_path} to {out_path}")