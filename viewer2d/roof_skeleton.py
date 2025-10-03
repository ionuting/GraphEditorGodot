import ezdxf
from shapely.geometry import Point, Polygon
import trimesh
import numpy as np
from scipy.spatial import Delaunay

# ---------------- Configurare ----------------
THICKNESS = 0.15  # Grosimea mesh-ului

# ---------------- Funcții ----------------

def read_control_circles(doc, layer="control"):
    """
    Citește toate cercurile de control de pe layer și extrage Z din XDATA QCAD.
    Dacă nu există XDATA, folosește z=0.
    """
    msp = doc.modelspace()
    control_points = []

    circles = list(msp.query(f"CIRCLE[layer=='{layer}']"))
    print(f"DEBUG: Cercuri găsite pe layer '{layer}': {len(circles)}")

    for c in circles:
        x, y = float(c.dxf.center[0]), float(c.dxf.center[1])
        z_value = 0.0  # fallback

        if c.has_xdata:
            try:
                xdata = c.get_xdata("QCAD")  # XDataSection
                for code, value in xdata:
                    if code == 1000 and isinstance(value, str) and value.startswith("z:"):
                        z_value = float(value.split(":")[1])
            except Exception as e:
                print(f"WARNING: Eroare la citirea XDATA pentru cerc ({x:.2f}, {y:.2f}): {e}")

        control_points.append((x, y, z_value))
        print(f"  - Cerc control ({x:.2f}, {y:.2f}) -> z={z_value}")

    if not control_points:
        print("WARNING: Niciun cerc de control găsit! Folosim z=0 pentru toate punctele.")
        control_points = [(0.0, 0.0, 0.0)]

    return control_points

def read_contours(doc, layer="IfcRoof"):
    """
    Citește toate poliliniile închise de pe layerul specificat.
    Include LWPOLYLINE și POLYLINE (vechi DXF).
    """
    msp = doc.modelspace()
    contours = []

    # Verifică toate entitățile de pe layer
    all_entities = list(msp.query(f"*[layer=='{layer}']"))
    print(f"\nDEBUG: Total entități pe layer '{layer}': {len(all_entities)}")
    
    entity_types = {}
    for ent in all_entities:
        ent_type = ent.dxftype()
        entity_types[ent_type] = entity_types.get(ent_type, 0) + 1
    
    for ent_type, count in entity_types.items():
        print(f"  - {ent_type}: {count}")

    # LWPOLYLINE
    lwpolylines = list(msp.query(f"LWPOLYLINE[layer=='{layer}']"))
    print(f"\nDEBUG: LWPOLYLINE găsite: {len(lwpolylines)}")
    
    for idx, pl in enumerate(lwpolylines, 1):
        points = list(pl.get_points())
        print(f"  - LWPOLYLINE #{idx}: Închisă={pl.closed}, Puncte={len(points)}")
        
        if pl.closed and len(points) >= 3:
            pts = [(float(p[0]), float(p[1])) for p in points]
            contours.append(pts)
            print(f"    ✓ Adăugat contur cu {len(pts)} puncte")
        else:
            print(f"    ✗ Ignorat (nu este închis sau are < 3 puncte)")

    # POLYLINE
    polylines = list(msp.query(f"POLYLINE[layer=='{layer}']"))
    print(f"\nDEBUG: POLYLINE găsite: {len(polylines)}")
    
    for idx, pl in enumerate(polylines, 1):
        vertices = list(pl.vertices)
        print(f"  - POLYLINE #{idx}: Închisă={pl.is_closed}, Vertices={len(vertices)}")
        
        if pl.is_closed and len(vertices) >= 3:
            pts = [(float(v.dxf.location[0]), float(v.dxf.location[1])) for v in vertices]
            contours.append(pts)
            print(f"    ✓ Adăugat contur cu {len(pts)} puncte")
        else:
            print(f"    ✗ Ignorat (nu este închis sau are < 3 vertices)")

    print(f"\n✅ Total contururi valide citite: {len(contours)}\n")
    return contours

def associate_z(contours, control_points):
    """
    Asociază coordonata Z fiecărui punct din contur cu cel mai apropiat cerc de control.
    """
    if not control_points:
        print("WARNING: Lista control_points este goală. Folosim z=0 pentru toate punctele.")
        control_points = [(0.0, 0.0, 0.0)]

    vertices = []
    for contour_idx, contour in enumerate(contours, start=1):
        contour_vertices = []
        print(f"Procesăm contur #{contour_idx} cu {len(contour)} puncte:")
        
        for pt_idx, pt in enumerate(contour, start=1):
            # cel mai apropiat punct de control
            closest = min(control_points, key=lambda c: (c[0]-pt[0])**2 + (c[1]-pt[1])**2)
            z_value = closest[2]
            contour_vertices.append((pt[0], pt[1], z_value))
            
            if pt_idx <= 3 or pt_idx == len(contour):  # Afișează primele 3 și ultimul punct
                dist = np.sqrt((closest[0]-pt[0])**2 + (closest[1]-pt[1])**2)
                print(f"  Punct {pt_idx}: ({pt[0]:.2f}, {pt[1]:.2f}) -> z={z_value:.2f} (dist={dist:.2f})")
        
        vertices.append(contour_vertices)
    
    return vertices

def build_mesh_with_thickness(vertices, thickness=THICKNESS):
    """
    Construiește mesh 3D cu grosime specificată.
    Creează două suprafețe (top și bottom) și le conectează cu fețe laterale.
    """
    if not vertices:
        raise ValueError("❌ Nu există contururi pentru a crea mesh!")
    
    all_meshes = []
    
    for idx, contour in enumerate(vertices, start=1):
        if len(contour) < 3:
            print(f"⚠ Contur #{idx} ignorat (< 3 puncte)")
            continue
        
        points = np.array(contour)
        points_2d = points[:, :2]  # Proiecție XY pentru triangulare
        
        try:
            # Triangulare Delaunay în plan XY
            tri = Delaunay(points_2d)
            
            # SUPRAFAȚA DE SUS (originală)
            top_vertices = points.copy()
            
            # SUPRAFAȚA DE JOS (offset cu thickness în jos pe Z)
            bottom_vertices = points.copy()
            bottom_vertices[:, 2] -= thickness
            
            # Combine vertices: prima jumătate = top, a doua jumătate = bottom
            all_vertices = np.vstack([top_vertices, bottom_vertices])
            
            # Fețe pentru suprafața de sus
            top_faces = tri.simplices.copy()
            
            # Fețe pentru suprafața de jos (inversate pentru orientare corectă)
            num_points = len(points)
            bottom_faces = tri.simplices.copy() + num_points
            bottom_faces = np.fliplr(bottom_faces)  # Inversează ordinea vârfurilor
            
            # Fețe laterale (conectează marginile top și bottom)
            side_faces = []
            num_contour_points = len(contour)
            
            for i in range(num_contour_points):
                next_i = (i + 1) % num_contour_points
                
                # Doi triunghiuri pentru fiecare segment lateral
                # Triunghi 1: top[i], bottom[i], bottom[next_i]
                side_faces.append([i, i + num_points, next_i + num_points])
                # Triunghi 2: top[i], bottom[next_i], top[next_i]
                side_faces.append([i, next_i + num_points, next_i])
            
            side_faces = np.array(side_faces)
            
            # Combină toate fețele
            all_faces = np.vstack([top_faces, bottom_faces, side_faces])
            
            # Creează mesh-ul
            mesh = trimesh.Trimesh(vertices=all_vertices, faces=all_faces)
            
            # Verifică și repară mesh-ul
            mesh.remove_duplicate_faces()
            mesh.remove_degenerate_faces()
            
            all_meshes.append(mesh)
            print(f"✓ Contur #{idx}: Mesh cu grosime creat - {len(all_vertices)} vertices, {len(all_faces)} fețe")
                
        except Exception as e:
            print(f"❌ Eroare la triangularea conturului #{idx}: {e}")
            continue
    
    if not all_meshes:
        raise ValueError("❌ Niciun mesh valid nu a putut fi creat!")
    
    # Combină toate meshurile într-unul singur
    print(f"\n🔗 Combinăm {len(all_meshes)} meshuri cu grosime {thickness}...")
    combined_mesh = trimesh.util.concatenate(all_meshes)
    
    print(f"✅ Mesh combinat: {len(combined_mesh.vertices)} vertices, {len(combined_mesh.faces)} fețe")
    print(f"   Grosime aplicată: {thickness}")
    
    return combined_mesh

# ---------------- MAIN ----------------
if __name__ == "__main__":
    dxf_file = "C:/Users/ionut.ciuntuc/Desktop/1SecondFloor.dxf"
    
    print("="*60)
    print("CITIRE FIȘIER DXF")
    print("="*60)
    
    try:
        doc = ezdxf.readfile(dxf_file)
        print(f"✅ Fișier DXF citit cu succes: {dxf_file}\n")
    except Exception as e:
        print(f"❌ Eroare la citirea fișierului: {e}")
        exit(1)

    # 1. Citește cercurile de control
    print("="*60)
    print("CITIRE CERCURI DE CONTROL")
    print("="*60)
    control_points = read_control_circles(doc, layer="control")

    # 2. Citește poliliniile închise
    print("="*60)
    print("CITIRE CONTURURI (POLILINII ÎNCHISE)")
    print("="*60)
    contours = read_contours(doc, layer="IfcRoof")
    
    if not contours:
        print("\n❌ EROARE: Nu s-au găsit contururi închise pe layer 'IfcRoof'!")
        print("Verifică:")
        print("  1. Numele layerului este corect?")
        print("  2. Poliliniile sunt efectiv închise în DXF?")
        print("  3. Există polilinii pe acest layer?")
        exit(1)

    # 3. Asociere Z la fiecare punct
    print("="*60)
    print("ASOCIERE COORDONATE Z")
    print("="*60)
    vertices = associate_z(contours, control_points)

    # 4. Construiește mesh 3D cu grosime
    print("\n" + "="*60)
    print("CONSTRUIRE MESH 3D CU GROSIME")
    print("="*60)
    
    try:
        mesh = build_mesh_with_thickness(vertices, thickness=THICKNESS)
    except Exception as e:
        print(f"\n❌ Eroare la construirea mesh-ului: {e}")
        exit(1)

    # 5. Vizualizare mesh interactiv
    print("\n" + "="*60)
    print("VIZUALIZARE MESH")
    print("="*60)
    print("Se deschide fereastra de vizualizare...")
    mesh.show()

    # 6. Opțional export OBJ/STL
    output_file = "roof_mesh.obj"
    mesh.export(output_file)
    print(f"\n✅ Mesh exportat cu succes: {output_file}")
    print("\n" + "="*60)
    print("FINALIZAT CU SUCCES!")
    print("="*60)