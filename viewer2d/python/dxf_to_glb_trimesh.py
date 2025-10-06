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
# Funcții pentru rotația în jurul primului segment
# -----------------------------
def create_inclined_mesh(points, height, angle_degrees):
    """
    Creează un mesh prin proiectarea conturului pe un plan înclinat și extrudarea pe normala planului.
    
    Args:
        points: lista de puncte (x, y) care definesc poligonul
        height: înălțimea extrudării
        angle_degrees: unghiul de înclinare în grade (pozitiv = antiorar, negativ = orar)
    
    Returns:
        mesh rezultat sau None dacă nu se poate crea
    """
    if len(points) < 3:
        return None
        
    try:
        # Primul segment este între punctele 0 și 1
        p1 = np.array([points[0][0], points[0][1], 0])  # Primul punct
        p2 = np.array([points[1][0], points[1][1], 0])  # Al doilea punct
        
        # Calculează vectorul primului segment (axa de rotație)
        segment_vector = p2 - p1
        segment_length = np.linalg.norm(segment_vector)
        
        if segment_length < 1e-6:
            print(f"[DEBUG] Primul segment prea scurt pentru înclinare: {segment_length}")
            return None
        
        # Normalizează vectorul pentru a obține axa de rotație
        rotation_axis = segment_vector / segment_length
        
        # Convertește unghiul din grade în radiani
        angle_radians = np.radians(angle_degrees)
        
        # Creează matricea de rotație folosind formula Rodriguez
        cos_angle = np.cos(angle_radians)
        sin_angle = np.sin(angle_radians)
        
        # Matricea antisimetrică pentru vectorul axei
        axis_cross_matrix = np.array([
            [0, -rotation_axis[2], rotation_axis[1]],
            [rotation_axis[2], 0, -rotation_axis[0]],
            [-rotation_axis[1], rotation_axis[0], 0]
        ])
        
        # Formula Rodriguez pentru matricea de rotație
        rotation_matrix = (np.eye(3) + 
                          sin_angle * axis_cross_matrix + 
                          (1 - cos_angle) * np.dot(axis_cross_matrix, axis_cross_matrix))
        
        # Calculează normala planului înclinat
        # Începem cu normala verticală (0, 0, 1) și o rotim
        original_normal = np.array([0, 0, 1])
        inclined_normal = rotation_matrix @ original_normal
        
        # Proiectează punctele pe planul înclinat
        # Pentru fiecare punct, calculează proiecția pe planul care trece prin primul punct
        projected_points_3d = []
        
        for point in points:
            # Punctul în spațiul 3D
            point_3d = np.array([point[0], point[1], 0])
            
            # Calculează distanța de la punct la planul înclinat
            # Planul trece prin p1 și are normala inclined_normal
            to_point = point_3d - p1
            distance_to_plane = np.dot(to_point, inclined_normal)
            
            # Proiectează punctul pe planul înclinat
            projected_point = point_3d - distance_to_plane * inclined_normal
            projected_points_3d.append(projected_point)
        
        # Creează poligonul din punctele proiectate
        # Pentru a crea un mesh valid, avem nevoie să definim fețele
        num_points = len(projected_points_3d)
        
        # Punctele de bază (pe planul înclinat)
        base_vertices = np.array(projected_points_3d)
        
        # Punctele de sus (extrudate pe direcția normală)
        top_vertices = base_vertices + height * inclined_normal
        
        # Combină toate vertexurile
        all_vertices = np.vstack([base_vertices, top_vertices])
        
        # Creează fețele folosind triangulare pentru poligoanele de bază și sus
        faces = []
        
        # Triangulează poligonul de bază și de sus
        # Pentru simplitate, folosim triangulare în ventilator din primul punct
        if num_points > 3:
            # Fața de jos (poligonul de bază) - triangulare în ventilator
            for i in range(1, num_points - 1):
                faces.append([0, i + 1, i])  # Orientarea corectă pentru fața de jos
            
            # Fața de sus (poligonul extrudat) - triangulare în ventilator
            for i in range(1, num_points - 1):
                faces.append([num_points, num_points + i, num_points + i + 1])  # Orientarea corectă pentru fața de sus
        else:
            # Pentru triunghiuri, fețele sunt simple
            faces.append([0, 2, 1])  # Fața de jos
            faces.append([num_points, num_points + 1, num_points + 2])  # Fața de sus
        
        # Fețele laterale - triunghiuri între bază și sus
        for i in range(num_points):
            next_i = (i + 1) % num_points
            # Două triunghiuri pentru fiecare latură
            faces.append([i, next_i, next_i + num_points])
            faces.append([i, next_i + num_points, i + num_points])
        
        # Creează mesh-ul
        mesh = trimesh.Trimesh(vertices=all_vertices, faces=faces)
        
        # Verifică și repară mesh-ul dacă este necesar
        try:
            if not mesh.is_watertight:
                print(f"[DEBUG] Mesh not watertight după proiecția pe planul înclinat")
            mesh.fix_normals()
        except Exception as ex:
            print(f"[DEBUG] Mesh validation warning: {ex}")
        
        print(f"[DEBUG] Created inclined mesh: angle={angle_degrees}°, normal={inclined_normal}, vertices={len(all_vertices)}, faces={len(faces)}")
        return mesh
        
    except Exception as ex:
        print(f"[DEBUG] Inclined mesh creation failed: {ex}")
        return None

# -----------------------------
# Funcții pentru tăierea elementelor la acoperiș
# -----------------------------
def trim_elements_to_roof(solids, mapping):
    """
    Taie elementele structurale (IfcWall, IfcCovering, IfcColumn) la fața inferioară a acoperișului.
    
    Args:
        solids: lista de mesh-uri
        mapping: lista de dicționare cu informații despre mesh-uri
    
    Returns:
        tuple: (solids_trimmed, mapping_updated)
    """
    # Identifică elementele de acoperiș și elementele de tăiat
    roof_meshes = []
    structural_elements = []
    other_elements = []
    
    uuid_to_mesh = {mesh.metadata.get("uuid"): mesh for mesh in solids}
    uuid_to_entry = {entry["uuid"]: entry for entry in mapping}
    
    for mesh in solids:
        layer = mesh.metadata.get("layer", "")
        
        # Identifică acoperișurile (pot avea diverse denumiri)
        if any(roof_keyword in layer.lower() for roof_keyword in ["roof", "slab", "ifcslab"]):
            roof_meshes.append(mesh)
            print(f"[DEBUG] Found roof element: {mesh.metadata.get('name', 'unknown')} on layer {layer}")
        
        # Identifică elementele structurale care trebuie tăiate
        elif layer in ["IfcWall", "IfcCovering", "IfcColumn"]:
            structural_elements.append(mesh)
            print(f"[DEBUG] Found structural element to trim: {mesh.metadata.get('name', 'unknown')} on layer {layer}")
        
        else:
            other_elements.append(mesh)
    
    if not roof_meshes:
        print("[DEBUG] No roof elements found, skipping structural trimming")
        return solids, mapping
    
    if not structural_elements:
        print("[DEBUG] No structural elements found to trim")
        return solids, mapping
    
    print(f"[DEBUG] Trimming {len(structural_elements)} structural elements to {len(roof_meshes)} roof elements")
    
    trimmed_elements = []
    updated_mapping = []
    
    # Procesează fiecare element structural
    for struct_mesh in structural_elements:
        struct_uuid = struct_mesh.metadata.get("uuid")
        struct_entry = uuid_to_entry.get(struct_uuid)
        
        if not struct_entry:
            trimmed_elements.append(struct_mesh)
            continue
        
        # Găsește intersecțiile cu toate acoperișurile
        intersections_found = False
        final_mesh = struct_mesh
        
        for roof_mesh in roof_meshes:
            try:
                # Calculează bounding box-urile pentru verificare rapidă
                struct_bounds = struct_mesh.bounds
                roof_bounds = roof_mesh.bounds
                
                # Verifică dacă există overlap în planul XY
                xy_overlap = not (
                    struct_bounds[1][0] < roof_bounds[0][0] or  # struct la stânga de roof
                    struct_bounds[0][0] > roof_bounds[1][0] or  # struct la dreapta de roof
                    struct_bounds[1][1] < roof_bounds[0][1] or  # struct în față de roof
                    struct_bounds[0][1] > roof_bounds[1][1]     # struct în spate de roof
                )
                
                if not xy_overlap:
                    continue
                
                # Calculează Z-ul minim al acoperișului (fața inferioară)
                roof_bottom_z = roof_bounds[0][2]
                struct_top_z = struct_bounds[1][2]
                
                print(f"[DEBUG] Struct {struct_mesh.metadata.get('name')} top: {struct_top_z:.3f}, Roof {roof_mesh.metadata.get('name')} bottom: {roof_bottom_z:.3f}")
                
                # Dacă elementul structural depășește acoperișul
                if struct_top_z > roof_bottom_z:
                    # Creează un plan de tăiere la Z-ul minim al acoperișului
                    cutting_plane_origin = [0, 0, roof_bottom_z]
                    cutting_plane_normal = [0, 0, 1]  # Plan orizontal
                    
                    # Taie mesh-ul structural
                    try:
                        trimmed_mesh = final_mesh.slice_plane(
                            plane_normal=cutting_plane_normal,
                            plane_origin=cutting_plane_origin,
                            cap=True  # Închide mesh-ul după tăiere
                        )
                        
                        if trimmed_mesh and hasattr(trimmed_mesh, 'vertices') and len(trimmed_mesh.vertices) > 0:
                            # Păstrează metadata originală
                            trimmed_mesh.metadata = dict(final_mesh.metadata)
                            final_mesh = trimmed_mesh
                            intersections_found = True
                            
                            print(f"[DEBUG] Trimmed {struct_mesh.metadata.get('name')} at Z={roof_bottom_z:.3f}")
                        else:
                            print(f"[DEBUG] Trimming resulted in empty mesh for {struct_mesh.metadata.get('name')}")
                    
                    except Exception as ex:
                        print(f"[DEBUG] Failed to trim {struct_mesh.metadata.get('name')}: {ex}")
            
            except Exception as ex:
                print(f"[DEBUG] Error processing roof intersection: {ex}")
        
        # Adaugă mesh-ul procesat (tăiat sau original)
        trimmed_elements.append(final_mesh)
        
        # Actualizează mapping-ul
        if struct_entry:
            updated_entry = dict(struct_entry)
            if intersections_found:
                updated_entry["trimmed_to_roof"] = True
            updated_mapping.append(updated_entry)
    
    # Combină toate elementele: acoperișuri + structurale tăiate + altele
    final_solids = roof_meshes + trimmed_elements + other_elements
    
    # Adaugă în mapping elementele care nu sunt structurale
    for mesh in roof_meshes + other_elements:
        mesh_uuid = mesh.metadata.get("uuid")
        entry = uuid_to_entry.get(mesh_uuid)
        if entry:
            updated_mapping.append(entry)
    
    print(f"[DEBUG] Structural trimming complete: {len(final_solids)} total elements")
    
    return final_solids, updated_mapping

def apply_xyz_rotations(mesh, rotate_x, rotate_y, rotate_z=0.0):
    """
    Aplică rotații pe axele X, Y și Z la un mesh deja extrudat.
    
    Args:
        mesh: trimesh object
        rotate_x: unghiul de rotație în jurul axei X în grade
        rotate_y: unghiul de rotație în jurul axei Y în grade  
        rotate_z: unghiul de rotație în jurul axei Z în grade
    
    Returns:
        mesh rotit sau mesh original dacă nu există rotații
    """
    if abs(rotate_x) < 1e-6 and abs(rotate_y) < 1e-6 and abs(rotate_z) < 1e-6:
        return mesh  # Nu sunt rotații de aplicat
    
    try:
        mesh_copy = mesh.copy()
        
        # Aplică rotațiile în ordine: Z, Y, X (pentru a păstra consistența cu standardele 3D)
        if abs(rotate_z) > 1e-6:
            angle_z_rad = np.radians(rotate_z)
            rotation_z = trimesh.transformations.rotation_matrix(angle_z_rad, [0, 0, 1])
            mesh_copy.apply_transform(rotation_z)
            print(f"[DEBUG] Applied Z rotation: {rotate_z}°")
        
        if abs(rotate_y) > 1e-6:
            angle_y_rad = np.radians(rotate_y)
            rotation_y = trimesh.transformations.rotation_matrix(angle_y_rad, [0, 1, 0])
            mesh_copy.apply_transform(rotation_y)
            print(f"[DEBUG] Applied Y rotation: {rotate_y}°")
        
        if abs(rotate_x) > 1e-6:
            angle_x_rad = np.radians(rotate_x)
            rotation_x = trimesh.transformations.rotation_matrix(angle_x_rad, [1, 0, 0])
            mesh_copy.apply_transform(rotation_x)
            print(f"[DEBUG] Applied X rotation: {rotate_x}°")
        
        print(f"[DEBUG] Applied XYZ rotations: X={rotate_x}°, Y={rotate_y}°, Z={rotate_z}°")
        return mesh_copy
        
    except Exception as ex:
        print(f"[DEBUG] XYZ rotation failed: {ex}")
        return mesh

# -----------------------------
# Procesare geometrie din blocuri
# -----------------------------
def process_block_geometry(doc, block_layout, insert_point, rotation_angle, 
                          scale_x, scale_y, scale_z, layer, insert_handle,
                          insert_xdata, mesh_name_count, mapping, solids, voids):
    """
    Procesează geometria dintr-un bloc DXF cu rotația în jurul punctului de inserție.
    
    Args:
        doc: documentul DXF
        block_layout: layout-ul blocului
        insert_point: punctul de inserție al blocului
        rotation_angle: rotația blocului în grade
        scale_x, scale_y, scale_z: scalarea blocului
        layer: layer-ul entității INSERT
        insert_handle: handle-ul entității INSERT
        insert_xdata: XDATA de pe entitatea INSERT
        mesh_name_count: counter pentru nume mesh-uri
        mapping: lista de mapping
        solids: lista de mesh-uri solide
        voids: lista de mesh-uri void
    """
    
    # Parsează XDATA de pe entitatea INSERT pentru parametri globali de bloc
    def parse_insert_xdata(xdata_dict):
        rotate_x_global = 0.0
        rotate_y_global = 0.0
        z_global = 0.0
        
        for appid_data in xdata_dict.values():
            for code, value in appid_data:
                if code == 1000:
                    sval = str(value)
                    if sval.startswith("rotate_x:") or sval.startswith("rotation_x:"):
                        try:
                            rotate_x_global = float(sval.split(":")[1])
                        except Exception:
                            pass
                    elif sval.startswith("rotate_y:") or sval.startswith("rotation_y:"):
                        try:
                            rotate_y_global = float(sval.split(":")[1])
                        except Exception:
                            pass
                    elif sval.startswith("z:"):
                        try:
                            z_global = float(sval.split(":")[1])
                        except Exception:
                            pass
        
        return rotate_x_global, rotate_y_global, z_global
    
    rotate_x_global, rotate_y_global, z_global = parse_insert_xdata(insert_xdata)
    
    if abs(rotate_x_global) > 1e-6 or abs(rotate_y_global) > 1e-6:
        print(f"[DEBUG] Block global rotations: X={rotate_x_global:.1f}°, Y={rotate_y_global:.1f}°")
    
    # Punctul de origine pentru rotații (punctul de inserție cu Z global)
    rotation_origin = np.array([insert_point.x, insert_point.y, z_global])
    
    # Procesează fiecare entitate din bloc
    for entity in block_layout:
        ent_type = entity.dxftype()
        
        # Extrage XDATA din entitatea din bloc
        entity_xdata = {}
        if entity.has_xdata:
            try:
                appids = []
                if hasattr(entity, "get_xdata_appids"):
                    appids = entity.get_xdata_appids()
                if "QCAD" not in appids:
                    appids.append("QCAD")
                
                for appid in appids:
                    try:
                        data = entity.get_xdata(appid)
                        if data:
                            entity_xdata[appid] = list(data)
                    except Exception:
                        pass
            except Exception:
                pass
        
        # Parsează parametrii entității din bloc (doar proprietăți geometrice)
        def parse_entity_xdata(xdata_list):
            height = 1.0  # Înălțimea extrudării
            name_str = ""  # Numele elementului
            solid_flag = 1  # Solid/void flag
            angle = 0.0  # Unghiul planului înclinat
            
            for code, value in xdata_list:
                if code == 1000:
                    sval = str(value)
                    if sval.startswith("height:"):
                        try:
                            height = float(sval.split(":")[1])
                        except Exception:
                            pass
                    elif sval.startswith("Name:"):
                        name_str = sval.split(":", 1)[1].strip()
                    elif sval.startswith("solid:"):
                        try:
                            solid_flag = int(sval.split(":")[1])
                        except Exception:
                            pass
                    elif sval.startswith("angle:"):
                        try:
                            angle = float(sval.split(":")[1])
                        except Exception:
                            pass
            
            return height, name_str, solid_flag, angle
        
        height, name_str, solid_flag, angle = parse_entity_xdata(
            entity_xdata.get("QCAD", [])
        )
        
        # Rotațiile finale sunt doar cele globale de pe bloc (nu mai adunăm cu elementele)
        final_rotate_x = rotate_x_global
        final_rotate_y = rotate_y_global
        
        # Generează numele mesh-ului: IfcType_ComponentLayer_Name
        entity_handle = getattr(entity, 'handle', f"block_{insert_handle}")
        entity_layer = getattr(entity, 'dxf', None)
        component_layer = getattr(entity_layer, 'layer', 'DefaultMaterial') if entity_layer else 'DefaultMaterial'
        
        # Materialul se bazează pe layer-ul componentei din bloc, nu pe layer-ul INSERT-ului
        rgba = get_material(component_layer)
        mesh_uuid = str(uuid.uuid4())
        
        # IfcType din layer-ul blocului (cu fallback pentru layer "0")
        ifc_type = layer if layer != "0" else "IfcWindow"  # Presupunem că blocurile pe layer 0 sunt ferestre
        
        # IfcType din layer-ul blocului, ComponentLayer din layer-ul entității, Name din XDATA
        key = (ifc_type, component_layer, name_str)
        mesh_name_count[key] = mesh_name_count.get(key, 0) + 1
        if name_str:
            mesh_name = f"{ifc_type}_{component_layer}_{name_str}_{mesh_name_count[key]}"
        else:
            mesh_name = f"{ifc_type}_{component_layer}_{mesh_name_count[key]}"
        
        # Procesează geometria entității
        mesh = None
        points = []
        
        if ent_type == "LWPOLYLINE":
            points = lwpolyline_to_points(entity, 16)
            closed = getattr(entity, "closed", False)
            
            if closed and len(points) >= 3:
                poly = Polygon(points)
                if poly.is_valid and poly.area > 0:
                    # Extrudare
                    if abs(angle) > 1e-6:
                        mesh = create_inclined_mesh(points, height, angle)
                    else:
                        mesh = extrude_polygon(poly, height)
                    
                    if mesh is not None:
                        # Scalare
                        if abs(scale_x - 1.0) > 1e-6 or abs(scale_y - 1.0) > 1e-6 or abs(scale_z - 1.0) > 1e-6:
                            scale_matrix = np.diag([scale_x, scale_y, scale_z, 1.0])
                            mesh.apply_transform(scale_matrix)
                        
                        # Translație la poziția globală (punctul de inserție + Z global)
                        mesh.apply_translation([insert_point.x, insert_point.y, z_global])
                        
                        # Rotația blocului în jurul axei Z (din DXF)
                        if abs(rotation_angle) > 1e-6:
                            z_rotation_matrix = trimesh.transformations.rotation_matrix(
                                np.radians(rotation_angle), [0, 0, 1], rotation_origin
                            )
                            mesh.apply_transform(z_rotation_matrix)
                        
                        # Rotațiile XYZ în jurul punctului de inserție
                        if abs(final_rotate_x) > 1e-6 or abs(final_rotate_y) > 1e-6:
                            mesh = apply_xyz_rotations_around_point(
                                mesh, final_rotate_x, final_rotate_y, 0.0, rotation_origin
                            )
                        
        elif ent_type == "POLYLINE":
            points = polyline_to_points(entity, 16)
            closed = getattr(entity, "is_closed", False)
            
            if closed and len(points) >= 3:
                poly = Polygon(points)
                if poly.is_valid and poly.area > 0:
                    # Extrudare
                    if abs(angle) > 1e-6:
                        mesh = create_inclined_mesh(points, height, angle)
                    else:
                        mesh = extrude_polygon(poly, height)
                    
                    if mesh is not None:
                        # Scalare
                        if abs(scale_x - 1.0) > 1e-6 or abs(scale_y - 1.0) > 1e-6 or abs(scale_z - 1.0) > 1e-6:
                            scale_matrix = np.diag([scale_x, scale_y, scale_z, 1.0])
                            mesh.apply_transform(scale_matrix)
                        
                        # Translație la poziția globală (punctul de inserție + Z global)
                        mesh.apply_translation([insert_point.x, insert_point.y, z_global])
                        
                        # Rotația blocului în jurul axei Z (din DXF)
                        if abs(rotation_angle) > 1e-6:
                            z_rotation_matrix = trimesh.transformations.rotation_matrix(
                                np.radians(rotation_angle), [0, 0, 1], rotation_origin
                            )
                            mesh.apply_transform(z_rotation_matrix)
                        
                        # Rotațiile XYZ în jurul punctului de inserție
                        if abs(final_rotate_x) > 1e-6 or abs(final_rotate_y) > 1e-6:
                            mesh = apply_xyz_rotations_around_point(
                                mesh, final_rotate_x, final_rotate_y, 0.0, rotation_origin
                            )
        
        elif ent_type == "CIRCLE" and hasattr(entity, "dxf"):
            center = (entity.dxf.center.x, entity.dxf.center.y)
            radius = entity.dxf.radius
            segments = 32
            points = [
                (
                    center[0] + np.cos(2 * np.pi * i / segments) * radius,
                    center[1] + np.sin(2 * np.pi * i / segments) * radius,
                )
                for i in range(segments)
            ]
            
            poly = Polygon(points)
            if poly.is_valid and poly.area > 0:
                # Extrudare
                if abs(angle) > 1e-6:
                    mesh = create_inclined_mesh(points, height, angle)
                else:
                    mesh = extrude_polygon(poly, height)
                
                if mesh is not None:
                    # Scalare
                    if abs(scale_x - 1.0) > 1e-6 or abs(scale_y - 1.0) > 1e-6 or abs(scale_z - 1.0) > 1e-6:
                        scale_matrix = np.diag([scale_x, scale_y, scale_z, 1.0])
                        mesh.apply_transform(scale_matrix)
                    
                    # Translație la poziția globală (punctul de inserție + Z global)
                    mesh.apply_translation([insert_point.x, insert_point.y, z_global])
                    
                    # Rotația blocului în jurul axei Z (din DXF)
                    if abs(rotation_angle) > 1e-6:
                        z_rotation_matrix = trimesh.transformations.rotation_matrix(
                            np.radians(rotation_angle), [0, 0, 1], rotation_origin
                        )
                        mesh.apply_transform(z_rotation_matrix)
                    
                    # Rotațiile XYZ în jurul punctului de inserție
                    if abs(final_rotate_x) > 1e-6 or abs(final_rotate_y) > 1e-6:
                        mesh = apply_xyz_rotations_around_point(
                            mesh, final_rotate_x, final_rotate_y, 0.0, rotation_origin
                        )
        
        # Adaugă mesh-ul la lista corespunzătoare și mapping
        if mesh is not None:
            # Setează metadata
            mesh.metadata = {
                "uuid": mesh_uuid,
                "name": mesh_name,
                "dxf_handle": entity_handle,
                "layer": component_layer,  # Layer-ul componentei pentru material
                "role": 0 if solid_flag == 0 else 1  # 0 = void, 1 = solid
            }
            
            # Setează culorile pe baza materialului componentei
            color = rgba[:3]
            alpha = rgba[3]
            rgba_float = np.array(color + [alpha], dtype=np.float32)
            mesh.visual.vertex_colors = np.tile(rgba_float, (len(mesh.vertices), 1))
            mesh.visual.material = trimesh.visual.material.PBRMaterial(
                baseColorFactor=[1.0, 1.0, 1.0, alpha],
                vertex_color=True,
                alphaMode="BLEND" if alpha < 1.0 else "OPAQUE"
            )
            
            print(f"[DEBUG] Block mesh colors: {mesh_name} | material_layer={component_layer} | color={color} alpha={alpha}")
            
            # Calculează proprietățile geometrice
            if len(points) >= 3:
                segment_lengths = [
                    np.linalg.norm(np.array(points[i]) - np.array(points[(i+1)%len(points)])) 
                    for i in range(len(points))
                ]
                perimeter = float(np.sum(segment_lengths))
                area = float(Polygon(points).area) if len(points) >= 3 else 0.0
                lateral_area = perimeter * height
                volume = area * height
            else:
                segment_lengths = []
                perimeter = 0.0
                area = 0.0
                lateral_area = 0.0
                volume = 0.0
            
            # Adaugă la mapping
            mapping_entry = {
                "dxf_handle": entity_handle,
                "mesh_name": mesh_name,
                "uuid": mesh_uuid,
                "role": 0 if solid_flag == 0 else 1,
                "solid_flag": solid_flag,
                "ifc_type": ifc_type,  # IfcType din layer-ul blocului (IfcWindow, IfcDoor, etc.)
                "component_layer": component_layer,  # Layer-ul componentei pentru material
                "material_layer": component_layer,  # Layer-ul pentru maparea materialului
                "block_name": f"From_{insert_handle}",  # Referință la blocul părinte
                "insert_position": {  # Poziția world a blocului
                    "x": float(insert_point.x),
                    "y": float(insert_point.y),
                    "z": z_global
                },
                "component_name": name_str,  # Numele componentei din XDATA
                "angle": angle,  # Parametri de pe elementul din bloc
                "height": height,  # Parametri de pe elementul din bloc (grosimea)
                "rotate_x": final_rotate_x,  # Rotații globale de pe bloc
                "rotate_y": final_rotate_y,  # Rotații globale de pe bloc
                "segment_lengths": segment_lengths,
                "perimeter": perimeter,
                "area": area,
                "lateral_area": lateral_area,
                "volume": volume,
                "vertices": [[float(p[0]), float(p[1])] for p in points],
                "is_cut_by": []
            }
            
            # Nu adăugăm mapping-ul aici - se va adăuga după procesarea boolean
            
            # Colectează mesh-urile pentru procesare boolean în cadrul blocului
            mesh.metadata["solid_flag"] = solid_flag
            mesh.metadata["component_layer"] = component_layer
            mesh.metadata["mapping_entry"] = mapping_entry
            
            if solid_flag == 0:
                print(f"[DEBUG] Block void: {mesh_name} | IfcType={ifc_type} | Material={component_layer} | rotate_x={final_rotate_x:.1f}°, rotate_y={final_rotate_y:.1f}°")
            else:
                print(f"[DEBUG] Block solid: {mesh_name} | IfcType={ifc_type} | Material={component_layer} | rotate_x={final_rotate_x:.1f}°, rotate_y={final_rotate_y:.1f}°")
            
            # Adaugă la lista temporară pentru procesare în bloc
            if not hasattr(process_block_geometry, '_block_meshes'):
                process_block_geometry._block_meshes = []
            process_block_geometry._block_meshes.append(mesh)
    
    # Procesează operațiile boolean în cadrul blocului
    if hasattr(process_block_geometry, '_block_meshes'):
        block_meshes = process_block_geometry._block_meshes
        process_block_geometry._block_meshes = []  # Reset pentru următorul bloc
        
        # Separă solid și void mesh-urile
        block_solids = []
        block_voids = []
        
        for mesh in block_meshes:
            if mesh.metadata.get("solid_flag", 1) == 0:
                block_voids.append(mesh)
            else:
                block_solids.append(mesh)
        
        print(f"[DEBUG] Block boolean processing: {len(block_solids)} solids, {len(block_voids)} voids")
        
        # Aplică operațiile boolean între componentele blocului
        final_block_meshes = []
        
        for solid_mesh in block_solids:
            current_mesh = solid_mesh
            solid_uuid = solid_mesh.metadata.get("uuid")
            cutting_voids = []
            
            # Aplică toate void-urile din bloc la acest solid
            for void_mesh in block_voids:
                void_uuid = void_mesh.metadata.get("uuid")
                try:
                    # Verifică intersecția bounding box
                    bb_intersect = not (
                        current_mesh.bounds[1][0] < void_mesh.bounds[0][0] or
                        current_mesh.bounds[0][0] > void_mesh.bounds[1][0] or
                        current_mesh.bounds[1][1] < void_mesh.bounds[0][1] or
                        current_mesh.bounds[0][1] > void_mesh.bounds[1][1] or
                        current_mesh.bounds[1][2] < void_mesh.bounds[0][2] or
                        current_mesh.bounds[0][2] > void_mesh.bounds[1][2]
                    )
                    
                    if bb_intersect:
                        try:
                            # Testează dacă se intersectează efectiv
                            intersection = current_mesh.intersection(void_mesh)
                            if intersection and hasattr(intersection, 'volume') and intersection.volume > 1e-6:
                                # Aplică operația boolean difference
                                diff_result = current_mesh.difference(void_mesh)
                                if diff_result and hasattr(diff_result, 'vertices') and len(diff_result.vertices) > 0:
                                    # Păstrează metadata originală
                                    diff_result.metadata = dict(current_mesh.metadata)
                                    current_mesh = diff_result
                                    cutting_voids.append(void_uuid)
                                    print(f"[DEBUG] Block void {void_uuid} cut solid {solid_uuid}")
                                else:
                                    print(f"[DEBUG] Block void {void_uuid} completely removed solid {solid_uuid}")
                                    current_mesh = None
                                    break
                        except Exception as ex:
                            print(f"[DEBUG] Block boolean operation failed: {ex}")
                except Exception as ex:
                    print(f"[DEBUG] Block bounds check failed: {ex}")
            
            # Adaugă mesh-ul final dacă nu a fost complet eliminat
            if current_mesh is not None:
                # Actualizează mapping-ul
                mapping_entry = current_mesh.metadata.get("mapping_entry")
                if mapping_entry:
                    mapping_entry["is_cut_by"] = cutting_voids
                    mapping.append(mapping_entry)
                
                final_block_meshes.append(current_mesh)
        
        # Adaugă și mesh-urile void separate (pentru debug/vizualizare)
        for void_mesh in block_voids:
            mapping_entry = void_mesh.metadata.get("mapping_entry")
            if mapping_entry:
                mapping.append(mapping_entry)
            # Nu adăugăm void-urile la solids - ele doar taie
        
        # Adaugă mesh-urile finale la listele globale
        for mesh in final_block_meshes:
            solids.append(mesh)
            print(f"[DEBUG] Final block mesh: {mesh.metadata.get('name')} | vertices={len(mesh.vertices)}")
        
        print(f"[DEBUG] Block processing complete: {len(final_block_meshes)} final meshes")

def apply_xyz_rotations_around_point(mesh, rotate_x, rotate_y, rotate_z, point):
    """
    Aplică rotații XYZ în jurul unui punct specific.
    
    Args:
        mesh: mesh-ul de rotit
        rotate_x, rotate_y, rotate_z: rotațiile în grade
        point: punctul în jurul căruia se fac rotațiile [x, y, z]
    
    Returns:
        mesh: mesh-ul rotit
    """
    if abs(rotate_x) < 1e-6 and abs(rotate_y) < 1e-6 and abs(rotate_z) < 1e-6:
        return mesh
    
    try:
        # Aplică rotațiile în ordinea: Z, Y, X
        if abs(rotate_z) > 1e-6:
            rotation_matrix = trimesh.transformations.rotation_matrix(
                np.radians(rotate_z), [0, 0, 1], point
            )
            mesh.apply_transform(rotation_matrix)
            print(f"[DEBUG] Applied Z rotation: {rotate_z:.1f}° around point {point}")
        
        if abs(rotate_y) > 1e-6:
            rotation_matrix = trimesh.transformations.rotation_matrix(
                np.radians(rotate_y), [0, 1, 0], point
            )
            mesh.apply_transform(rotation_matrix)
            print(f"[DEBUG] Applied Y rotation: {rotate_y:.1f}° around point {point}")
        
        if abs(rotate_x) > 1e-6:
            rotation_matrix = trimesh.transformations.rotation_matrix(
                np.radians(rotate_x), [1, 0, 0], point
            )
            mesh.apply_transform(rotation_matrix)
            print(f"[DEBUG] Applied X rotation: {rotate_x:.1f}° around point {point}")
        
        print(f"[DEBUG] Applied XYZ rotations around point: X={rotate_x:.1f}°, Y={rotate_y:.1f}°, Z={rotate_z:.1f}°")
        
    except Exception as e:
        print(f"[DEBUG] Error applying XYZ rotations around point: {e}")
    
    return mesh

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

        # Procesare specială pentru blocurile de ferestre
        if ent_type == "INSERT" and layer == "IfcWindow":
            block_name = getattr(e.dxf, "name", "")
            insert_point = getattr(e.dxf, "insert", None)
            rotation_angle = getattr(e.dxf, "rotation", 0.0)  # Rotația în grade
            
            if insert_point and block_name:
                # Parsează XDATA pentru Z
                z_position = 0.0
                window_height = 1.2  # Înălțime implicită pentru ferestre
                window_name = block_name
                
                if e.has_xdata:
                    try:
                        appids = []
                        if hasattr(e, "get_xdata_appids"):
                            appids = e.get_xdata_appids()
                        if "QCAD" not in appids:
                            appids.append("QCAD")
                        
                        for appid in appids:
                            try:
                                xdata_qcad = e.get_xdata(appid)
                                if xdata_qcad:
                                    for code, value in xdata_qcad:
                                        if code == 1000:
                                            sval = str(value)
                                            if sval.startswith("z:"):
                                                try:
                                                    z_position = float(sval.split(":")[1])
                                                except Exception:
                                                    pass
                                            elif sval.startswith("height:"):
                                                try:
                                                    window_height = float(sval.split(":")[1])
                                                except Exception:
                                                    pass
                                            elif sval.startswith("Name:"):
                                                window_name = sval.split(":", 1)[1].strip()
                                    break  # După ce găsim XDATA valid, ieșim
                            except Exception as ex:
                                print(f"[DEBUG] XDATA appid {appid} error: {ex}")
                    except Exception as ex:
                        print(f"[DEBUG] XDATA parsing error for window block: {ex}")
                
                # Creează entry pentru mapping
                window_uuid = str(uuid.uuid4())
                window_entry = {
                    "dxf_handle": handle,
                    "block_name": block_name,
                    "window_name": window_name,
                    "uuid": window_uuid,
                    "type": "window_block",
                    "layer": layer,
                    "gltf_file": f"library/gltf library/Windows/{block_name}.gltf",
                    "position": {
                        "x": float(insert_point.x),
                        "y": float(insert_point.y), 
                        "z": z_position
                    },
                    "rotation": {
                        "z": rotation_angle  # Rotația în jurul axei Z în grade
                    },
                    "scale": {
                        "x": 1.0,
                        "y": 1.0,
                        "z": 1.0
                    },
                    "height": window_height
                }
                
                mapping.append(window_entry)
                print(f"[DEBUG] Added window block: {block_name} at ({insert_point.x:.2f}, {insert_point.y:.2f}, {z_position:.2f}) rotation={rotation_angle:.1f}°")
                continue  # Nu procesăm blocul ca geometrie normală

        # Procesare pentru blocurile cu geometrie (INSERT cu conținut solid)
        if ent_type == "INSERT" and layer != "IfcWindow":
            block_name = getattr(e.dxf, "name", "")
            insert_point = getattr(e.dxf, "insert", None)
            rotation_angle = getattr(e.dxf, "rotation", 0.0)  # Rotația în grade
            scale_x = getattr(e.dxf, "xscale", 1.0)
            scale_y = getattr(e.dxf, "yscale", 1.0)
            scale_z = getattr(e.dxf, "zscale", 1.0)
            
            if insert_point is not None and block_name:
                # Încearcă să găsească blocul în document
                try:
                    print(f"[DEBUG] Looking for block: {block_name}")
                    block_layout = doc.blocks.get(block_name)
                    if block_layout:
                        # Procesează geometria din bloc cu punctul de inserție ca origine pentru rotații
                        print(f"[DEBUG] Processing geometry block: {block_name} at ({insert_point.x:.2f}, {insert_point.y:.2f})")
                        process_block_geometry(
                            doc, block_layout, insert_point, rotation_angle, 
                            scale_x, scale_y, scale_z, layer, handle, 
                            xdata, mesh_name_count, mapping, solids, voids
                        )
                        continue  # Blocul a fost procesat, trecem la următoarea entitate
                    else:
                        print(f"[DEBUG] Block not found: {block_name}")
                except Exception as ex:
                    print(f"[DEBUG] Error processing block {block_name}: {ex}")
                    # Continuă cu procesarea normală dacă blocul nu poate fi procesat

        def parse_xdata_from_list(xdata_list):
            height, z = 1.0, 0.0
            name_str = ""
            solid_flag = 1  # Implicit solid, doar dacă e explicit setat pe 0 devine void
            angle = 0.0  # Unghiul de rotație în grade (implicit 0)
            rotate_x = 0.0  # Rotația în jurul axei X în grade
            rotate_y = 0.0  # Rotația în jurul axei Y în grade
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
                    elif sval.startswith("angle:"):
                        try:
                            angle = float(sval.split(":")[1])
                        except Exception:
                            pass
                    elif sval.startswith("rotate_x:"):
                        try:
                            rotate_x = float(sval.split(":")[1])
                        except Exception:
                            pass
                    elif sval.startswith("rotate_y:"):
                        try:
                            rotate_y = float(sval.split(":")[1])
                        except Exception:
                            pass
            return height, z, name_str, solid_flag, angle, rotate_x, rotate_y

        height, z, name_str, solid_flag, angle, rotate_x, rotate_y = parse_xdata_from_list(xdata.get("QCAD", []))
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
                    if abs(angle) > 1e-6:
                        # Creează mesh pe planul înclinat
                        mesh = create_inclined_mesh(points, height, angle)
                    else:
                        # Mesh orizontal standard
                        mesh = extrude_polygon(poly, height)
                    
                    if mesh is not None:
                        mesh.apply_translation([0, 0, z])
                        # Aplică rotațiile suplimentare pe axele X și Y
                        if abs(rotate_x) > 1e-6 or abs(rotate_y) > 1e-6:
                            mesh = apply_xyz_rotations(mesh, rotate_x, rotate_y, 0.0)

        # Procesare POLYLINE cu suport pentru arce
        elif ent_type == "POLYLINE":
            points = polyline_to_points(e, arc_segments)
            closed = getattr(e, "is_closed", False)
            if closed and len(points) >= 3:
                poly = Polygon(points)
                if poly.is_valid and poly.area > 0:
                    if abs(angle) > 1e-6:
                        # Creează mesh pe planul înclinat
                        mesh = create_inclined_mesh(points, height, angle)
                    else:
                        # Mesh orizontal standard
                        mesh = extrude_polygon(poly, height)
                    
                    if mesh is not None:
                        mesh.apply_translation([0, 0, z])
                        # Aplică rotațiile suplimentare pe axele X și Y
                        if abs(rotate_x) > 1e-6 or abs(rotate_y) > 1e-6:
                            mesh = apply_xyz_rotations(mesh, rotate_x, rotate_y, 0.0)

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
                if abs(angle) > 1e-6:
                    # Creează mesh pe planul înclinat
                    mesh = create_inclined_mesh(points, height, angle)
                else:
                    # Mesh orizontal standard
                    mesh = extrude_polygon(poly, height)
                
                if mesh is not None:
                    mesh.apply_translation([0, 0, z])
                    # Aplică rotațiile suplimentare pe axele X și Y
                    if abs(rotate_x) > 1e-6 or abs(rotate_y) > 1e-6:
                        mesh = apply_xyz_rotations(mesh, rotate_x, rotate_y, 0.0)

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
                "angle": angle,
                "rotate_x": rotate_x,
                "rotate_y": rotate_y,
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
                "angle": angle,
                "rotate_x": rotate_x,
                "rotate_y": rotate_y,
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

    # Separează voidurile și solidele pentru aplicarea logicii globale
    global_voids = []
    layer_voids_by_layer = {}  # Pentru voidurile cu solid_flag=0 (per layer)
    all_solids = []
    
    for mesh in solids + voids:
        layer = mesh.metadata.get("layer", "default")
        
        if mesh.metadata.get("is_void", False):
            if layer == "void":
                # Layerul "void" taie toate geometriile
                global_voids.append(mesh)
            else:
                # Voiduri pe alte layere (solid_flag=0) taie doar același layer
                if layer not in layer_voids_by_layer:
                    layer_voids_by_layer[layer] = []
                layer_voids_by_layer[layer].append(mesh)
        else:
            all_solids.append(mesh)

    print(f"[DEBUG] Global voids (layer 'void'): {len(global_voids)}")
    print(f"[DEBUG] Layer-specific voids: {sum(len(v) for v in layer_voids_by_layer.values())}")
    print(f"[DEBUG] All solids: {len(all_solids)}")

    new_solids = []
    
    # Prima etapă: Aplică voidurile globale (layerul "void") la toate solidele
    if global_voids:
        global_void_union = trimesh.util.concatenate(global_voids)
        print("[DEBUG] Applying global voids to all solids...")
        
        for mesh in all_solids:
            solid_uuid = mesh.metadata.get("uuid")
            cutting_voids = []
            
            # Verifică care voiduri globale taie acest solid
            for void_mesh in global_voids:
                void_uuid = void_mesh.metadata.get("uuid")
                try:
                    # Verificare prin intersecția bounding box-urilor
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
                                solid_layer = mesh.metadata.get("layer", "default")
                                print(f"[DEBUG] Global void {void_uuid} cuts solid {solid_uuid} (layer {solid_layer})")
                        except Exception as ex:
                            print(f"[DEBUG] Global intersection test failed: {ex}")
                except Exception as ex:
                    print(f"[DEBUG] Global bounds check failed: {ex}")
            
            # Aplică tăierea cu voidurile globale
            try:
                diff = mesh.difference(global_void_union)
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
                print(f"[DEBUG] Global boolean difference failed for mesh {solid_uuid}: {ex}")
                new_solids.append(mesh)
            
            # Actualizează mapping-ul cu voidurile globale
            if solid_uuid in uuid_to_entry:
                existing_cuts = uuid_to_entry[solid_uuid].get("is_cut_by", [])
                uuid_to_entry[solid_uuid]["is_cut_by"] = existing_cuts + cutting_voids
    else:
        # Nu există voiduri globale, copiază solidele
        new_solids = all_solids.copy()

    # A doua etapă: Aplică voidurile specifice pe layer (solid_flag=0)
    final_solids = []
    solids_by_layer = {}
    
    # Grupează solidele rezultate pe layere
    for mesh in new_solids:
        layer = mesh.metadata.get("layer", "default")
        if layer not in solids_by_layer:
            solids_by_layer[layer] = []
        solids_by_layer[layer].append(mesh)
    
    # Logică specială pentru IfcWindow voids
    window_voids = layer_voids_by_layer.get("IfcWindow", [])
    if window_voids:
        print(f"[DEBUG] Applying IfcWindow voids to IfcWall and IfcCovering: {len(window_voids)} voids")
        window_void_union = trimesh.util.concatenate(window_voids)
        
        # IfcWindow voids taie doar IfcWall și IfcCovering
        target_layers = ["IfcWall", "IfcCovering"]
        for target_layer in target_layers:
            if target_layer in solids_by_layer:
                layer_solids = solids_by_layer[target_layer]
                processed_solids = []
                
                for mesh in layer_solids:
                    solid_uuid = mesh.metadata.get("uuid")
                    cutting_voids = []
                    
                    # Verifică care window voids taie acest solid
                    for void_mesh in window_voids:
                        void_uuid = void_mesh.metadata.get("uuid")
                        try:
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
                                        print(f"[DEBUG] IfcWindow void {void_uuid} cuts {target_layer} solid {solid_uuid}")
                                except Exception as ex:
                                    print(f"[DEBUG] IfcWindow intersection test failed: {ex}")
                        except Exception as ex:
                            print(f"[DEBUG] IfcWindow bounds check failed: {ex}")
                    
                    # Aplică tăierea cu window voids
                    try:
                        diff = mesh.difference(window_void_union)
                        if diff:
                            if isinstance(diff, list):
                                for dmesh in diff:
                                    dmesh.metadata = dict(mesh.metadata) if hasattr(mesh, 'metadata') else {}
                                    processed_solids.append(dmesh)
                            else:
                                diff.metadata = dict(mesh.metadata) if hasattr(mesh, 'metadata') else {}
                                processed_solids.append(diff)
                        else:
                            processed_solids.append(mesh)
                    except Exception as ex:
                        print(f"[DEBUG] IfcWindow boolean difference failed for mesh {solid_uuid}: {ex}")
                        processed_solids.append(mesh)
                    
                    # Actualizează mapping-ul cu window voids
                    if solid_uuid in uuid_to_entry:
                        existing_cuts = uuid_to_entry[solid_uuid].get("is_cut_by", [])
                        uuid_to_entry[solid_uuid]["is_cut_by"] = existing_cuts + cutting_voids
                
                # Înlocuiește solidele procesate
                solids_by_layer[target_layer] = processed_solids
    
    # Aplică voidurile normale pe layer (exclude IfcWindow care a fost deja procesat)
    for layer, layer_solids in solids_by_layer.items():
        if layer in layer_voids_by_layer and layer != "IfcWindow":
            layer_voids = layer_voids_by_layer[layer]
            layer_void_union = trimesh.util.concatenate(layer_voids)
            
            print(f"[DEBUG] Applying layer-specific voids for layer '{layer}': {len(layer_voids)} voids")
            
            processed_solids = []
            for mesh in layer_solids:
                solid_uuid = mesh.metadata.get("uuid")
                cutting_voids = []
                
                # Verifică care voiduri din același layer taie acest solid
                for void_mesh in layer_voids:
                    void_uuid = void_mesh.metadata.get("uuid")
                    try:
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
                                    print(f"[DEBUG] Layer void {void_uuid} cuts solid {solid_uuid} (both on layer {layer})")
                            except Exception as ex:
                                print(f"[DEBUG] Layer intersection test failed: {ex}")
                    except Exception as ex:
                        print(f"[DEBUG] Layer bounds check failed: {ex}")
                
                # Aplică tăierea cu voidurile de layer
                try:
                    diff = mesh.difference(layer_void_union)
                    if diff:
                        if isinstance(diff, list):
                            for dmesh in diff:
                                dmesh.metadata = dict(mesh.metadata) if hasattr(mesh, 'metadata') else {}
                                processed_solids.append(dmesh)
                        else:
                            diff.metadata = dict(mesh.metadata) if hasattr(mesh, 'metadata') else {}
                            processed_solids.append(diff)
                    else:
                        processed_solids.append(mesh)
                except Exception as ex:
                    print(f"[DEBUG] Layer boolean difference failed for mesh {solid_uuid}: {ex}")
                    processed_solids.append(mesh)
                
                # Actualizează mapping-ul cu voidurile de layer
                if solid_uuid in uuid_to_entry:
                    existing_cuts = uuid_to_entry[solid_uuid].get("is_cut_by", [])
                    uuid_to_entry[solid_uuid]["is_cut_by"] = existing_cuts + cutting_voids
            
            solids_by_layer[layer] = processed_solids
    
    # Colectează toate solidele finale
    for layer_solids in solids_by_layer.values():
        final_solids.extend(layer_solids)
    
    solids = final_solids

    # Taie elementele structurale la acoperiș
    solids, mapping = trim_elements_to_roof(solids, mapping)

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