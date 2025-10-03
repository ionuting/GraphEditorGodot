import ezdxf
from shapely.geometry import Point, Polygon, LineString
import trimesh
import numpy as np
from scipy.spatial import Delaunay

# ---------------- Configurare ----------------
THICKNESS = 0.15  # Grosimea acoperiș

# Dimensiuni structură șarpantă (metri)
CAPRIORI_SPACING = 0.60  # Distanță între capriori
CAPRIORI_SECTION = (0.05, 0.12)  # Secțiune caprior (lățime x înălțime)

GRINZI_SPACING = 1.20  # Distanță între grinzi
GRINZI_SECTION = (0.08, 0.16)  # Secțiune grindă

POPI_SPACING = 2.40  # Distanță între popi
POPI_SECTION = (0.10, 0.10)  # Secțiune pop

OFFSET_CAPRIORI = 0.05  # Distanță sub acoperiș pentru capriori
OFFSET_GRINZI = 0.30  # Distanță sub capriori pentru grinzi
OFFSET_POPI = 0.60  # Distanță sub grinzi pentru popi

# ---------------- Funcții citire DXF ----------------

def read_control_circles(doc, layer="control"):
    """Citește cercurile de control cu Z din XDATA."""
    msp = doc.modelspace()
    control_points = []

    circles = list(msp.query(f"CIRCLE[layer=='{layer}']"))
    print(f"DEBUG: Cercuri găsite pe layer '{layer}': {len(circles)}")

    for c in circles:
        x, y = float(c.dxf.center[0]), float(c.dxf.center[1])
        z_value = 0.0

        if c.has_xdata:
            try:
                xdata = c.get_xdata("QCAD")
                for code, value in xdata:
                    if code == 1000 and isinstance(value, str) and value.startswith("z:"):
                        z_value = float(value.split(":")[1])
            except Exception as e:
                print(f"WARNING: Eroare XDATA pentru cerc ({x:.2f}, {y:.2f}): {e}")

        control_points.append((x, y, z_value))
        print(f"  - Cerc control ({x:.2f}, {y:.2f}) -> z={z_value}")

    if not control_points:
        print("WARNING: Niciun cerc de control găsit!")
        control_points = [(0.0, 0.0, 0.0)]

    return control_points

def read_contours(doc, layer="IfcRoof"):
    """Citește poliliniile închise."""
    msp = doc.modelspace()
    contours = []

    all_entities = list(msp.query(f"*[layer=='{layer}']"))
    print(f"\nDEBUG: Total entități pe layer '{layer}': {len(all_entities)}")

    # LWPOLYLINE
    lwpolylines = list(msp.query(f"LWPOLYLINE[layer=='{layer}']"))
    print(f"DEBUG: LWPOLYLINE găsite: {len(lwpolylines)}")
    
    for idx, pl in enumerate(lwpolylines, 1):
        points = list(pl.get_points())
        if pl.closed and len(points) >= 3:
            pts = [(float(p[0]), float(p[1])) for p in points]
            contours.append(pts)
            print(f"  ✓ LWPOLYLINE #{idx}: {len(pts)} puncte")

    # POLYLINE
    polylines = list(msp.query(f"POLYLINE[layer=='{layer}']"))
    print(f"DEBUG: POLYLINE găsite: {len(polylines)}")
    
    for idx, pl in enumerate(polylines, 1):
        vertices = list(pl.vertices)
        if pl.is_closed and len(vertices) >= 3:
            pts = [(float(v.dxf.location[0]), float(v.dxf.location[1])) for v in vertices]
            contours.append(pts)
            print(f"  ✓ POLYLINE #{idx}: {len(pts)} puncte")

    print(f"✅ Total contururi: {len(contours)}\n")
    return contours

def associate_z(contours, control_points):
    """Asociază Z din cercurile de control."""
    if not control_points:
        control_points = [(0.0, 0.0, 0.0)]

    vertices = []
    for contour_idx, contour in enumerate(contours, start=1):
        contour_vertices = []
        print(f"Procesăm contur #{contour_idx}:")
        
        for pt in contour:
            closest = min(control_points, key=lambda c: (c[0]-pt[0])**2 + (c[1]-pt[1])**2)
            z_value = closest[2]
            contour_vertices.append((pt[0], pt[1], z_value))
        
        vertices.append(contour_vertices)
    
    return vertices

# ---------------- Funcții mesh acoperiș ----------------

def build_roof_mesh(vertices, thickness=THICKNESS):
    """Construiește mesh acoperiș cu grosime."""
    if not vertices:
        raise ValueError("Nu există contururi!")
    
    all_meshes = []
    
    for idx, contour in enumerate(vertices, start=1):
        if len(contour) < 3:
            continue
        
        points = np.array(contour)
        points_2d = points[:, :2]
        
        try:
            tri = Delaunay(points_2d)
            
            top_vertices = points.copy()
            bottom_vertices = points.copy()
            bottom_vertices[:, 2] -= thickness
            
            all_vertices = np.vstack([top_vertices, bottom_vertices])
            num_points = len(points)
            
            top_faces = tri.simplices.copy()
            bottom_faces = tri.simplices.copy() + num_points
            bottom_faces = np.fliplr(bottom_faces)
            
            side_faces = []
            num_contour_points = len(contour)
            
            for i in range(num_contour_points):
                next_i = (i + 1) % num_contour_points
                side_faces.append([i, i + num_points, next_i + num_points])
                side_faces.append([i, next_i + num_points, next_i])
            
            side_faces = np.array(side_faces)
            all_faces = np.vstack([top_faces, bottom_faces, side_faces])
            
            mesh = trimesh.Trimesh(vertices=all_vertices, faces=all_faces)
            mesh.remove_duplicate_faces()
            mesh.remove_degenerate_faces()
            
            all_meshes.append(mesh)
            print(f"✓ Acoperiș #{idx}: {len(all_vertices)} vertices, {len(all_faces)} fețe")
                
        except Exception as e:
            print(f"❌ Eroare contur #{idx}: {e}")
            continue
    
    if not all_meshes:
        raise ValueError("Niciun mesh valid!")
    
    combined = trimesh.util.concatenate(all_meshes)
    print(f"✅ Mesh acoperiș: {len(combined.vertices)} vertices, {len(combined.faces)} fețe\n")
    
    return combined

# ---------------- Funcții structură șarpantă ----------------

def create_beam(start, end, width, height):
    """
    Creează o grindă dreptunghiulară între două puncte 3D.
    """
    start = np.array(start)
    end = np.array(end)
    
    # Vector direcție
    direction = end - start
    length = np.linalg.norm(direction)
    direction = direction / length
    
    # Sistem de coordonate local
    if abs(direction[2]) < 0.99:
        up = np.array([0, 0, 1])
    else:
        up = np.array([1, 0, 0])
    
    right = np.cross(direction, up)
    right = right / np.linalg.norm(right)
    up = np.cross(right, direction)
    up = up / np.linalg.norm(up)
    
    # 8 vârfuri ale grinzii
    hw = width / 2
    hh = height / 2
    
    vertices = []
    for l in [0, length]:
        for w in [-hw, hw]:
            for h in [-hh, hh]:
                point = start + l * direction + w * right + h * up
                vertices.append(point)
    
    vertices = np.array(vertices)
    
    # 12 triunghiuri (6 fețe x 2)
    faces = [
        [0, 1, 3], [0, 3, 2],  # Fața din spate
        [4, 6, 7], [4, 7, 5],  # Fața din față
        [0, 2, 6], [0, 6, 4],  # Fața stângă
        [1, 5, 7], [1, 7, 3],  # Fața dreaptă
        [0, 4, 5], [0, 5, 1],  # Fața de jos
        [2, 3, 7], [2, 7, 6],  # Fața de sus
    ]
    
    return trimesh.Trimesh(vertices=vertices, faces=faces)

def get_z_at_point(contour_vertices, x, y):
    """
    Calculează Z pentru un punct (x,y) pe suprafața definită de contur.
    Folosește interpolarea din triunghiurile Delaunay.
    """
    points = np.array(contour_vertices)
    points_2d = points[:, :2]
    
    tri = Delaunay(points_2d)
    simplex = tri.find_simplex([x, y])
    
    if simplex == -1:
        # Punct în afara conturului - folosește cel mai apropiat
        distances = np.sqrt((points_2d[:, 0] - x)**2 + (points_2d[:, 1] - y)**2)
        closest_idx = np.argmin(distances)
        return points[closest_idx, 2]
    
    # Interpolează Z din triunghiul găsit
    triangle_indices = tri.simplices[simplex]
    triangle_points = points[triangle_indices]
    
    # Coordonate baricentrice
    p = np.array([x, y])
    p0, p1, p2 = triangle_points[:, :2]
    
    v0 = p1 - p0
    v1 = p2 - p0
    v2 = p - p0
    
    d00 = np.dot(v0, v0)
    d01 = np.dot(v0, v1)
    d11 = np.dot(v1, v1)
    d20 = np.dot(v2, v0)
    d21 = np.dot(v2, v1)
    
    denom = d00 * d11 - d01 * d01
    if abs(denom) < 1e-10:
        return triangle_points[0, 2]
    
    v = (d11 * d20 - d01 * d21) / denom
    w = (d00 * d21 - d01 * d20) / denom
    u = 1.0 - v - w
    
    z = u * triangle_points[0, 2] + v * triangle_points[1, 2] + w * triangle_points[2, 2]
    return z

def build_truss_structure(contour_vertices):
    """
    Construiește structura completă de șarpantă:
    - Capriori (paraleli cu panta)
    - Grinzi (sub capriori)
    - Popi (verticali)
    """
    all_beams = []
    
    for contour in contour_vertices:
        points = np.array(contour)
        
        # Găsește bounding box
        min_x, min_y = points[:, :2].min(axis=0)
        max_x, max_y = points[:, :2].max(axis=0)
        
        print(f"\n🏗️ Construim șarpantă pentru contur:")
        print(f"   Dimensiuni: {max_x-min_x:.2f} x {max_y-min_y:.2f}")
        
        # === CAPRIORI (paraleli cu panta) ===
        print(f"\n📐 Generăm capriori (spacing={CAPRIORI_SPACING}m)...")
        num_capriori = int((max_y - min_y) / CAPRIORI_SPACING) + 1
        
        for i in range(num_capriori):
            y = min_y + i * CAPRIORI_SPACING
            if y > max_y:
                break
            
            # Puncte de start și end pe direcția X
            x_start, x_end = min_x, max_x
            z_start = get_z_at_point(contour, x_start, y) - OFFSET_CAPRIORI
            z_end = get_z_at_point(contour, x_end, y) - OFFSET_CAPRIORI
            
            start = [x_start, y, z_start]
            end = [x_end, y, z_end]
            
            beam = create_beam(start, end, CAPRIORI_SECTION[0], CAPRIORI_SECTION[1])
            all_beams.append(beam)
        
        print(f"   ✓ {len(all_beams)} capriori generați")
        
        # === GRINZI (perpendiculare pe capriori, sub ei) ===
        print(f"\n📐 Generăm grinzi (spacing={GRINZI_SPACING}m)...")
        num_grinzi_initial = len(all_beams)
        num_grinzi = int((max_x - min_x) / GRINZI_SPACING) + 1
        
        for i in range(num_grinzi):
            x = min_x + i * GRINZI_SPACING
            if x > max_x:
                break
            
            y_start, y_end = min_y, max_y
            z_start = get_z_at_point(contour, x, y_start) - OFFSET_CAPRIORI - OFFSET_GRINZI
            z_end = get_z_at_point(contour, x, y_end) - OFFSET_CAPRIORI - OFFSET_GRINZI
            
            start = [x, y_start, z_start]
            end = [x, y_end, z_end]
            
            beam = create_beam(start, end, GRINZI_SECTION[0], GRINZI_SECTION[1])
            all_beams.append(beam)
        
        print(f"   ✓ {len(all_beams) - num_grinzi_initial} grinzi generate")
        
        # === POPI (verticali, sub grinzi) ===
        print(f"\n📐 Generăm popi verticali (spacing={POPI_SPACING}m)...")
        num_popi_initial = len(all_beams)
        num_popi_x = int((max_x - min_x) / POPI_SPACING) + 1
        num_popi_y = int((max_y - min_y) / POPI_SPACING) + 1
        
        for i in range(num_popi_x):
            x = min_x + i * POPI_SPACING
            if x > max_x:
                break
            
            for j in range(num_popi_y):
                y = min_y + j * POPI_SPACING
                if y > max_y:
                    break
                
                z_top = get_z_at_point(contour, x, y) - OFFSET_CAPRIORI - OFFSET_GRINZI
                z_bottom = z_top - OFFSET_POPI
                
                start = [x, y, z_bottom]
                end = [x, y, z_top]
                
                beam = create_beam(start, end, POPI_SECTION[0], POPI_SECTION[1])
                all_beams.append(beam)
        
        print(f"   ✓ {len(all_beams) - num_popi_initial} popi generați")
    
    if not all_beams:
        raise ValueError("Nu s-au putut genera elemente structură!")
    
    print(f"\n✅ Total elemente structură: {len(all_beams)}")
    combined = trimesh.util.concatenate(all_beams)
    return combined

# ---------------- MAIN ----------------
if __name__ == "__main__":
    dxf_file = "C:/Users/ionut.ciuntuc/Desktop/1SecondFloor.dxf"
    
    print("="*60)
    print("GENERATOR STRUCTURĂ ȘARPANTĂ 3D")
    print("="*60)
    
    # Citire DXF
    try:
        doc = ezdxf.readfile(dxf_file)
        print(f"✅ Fișier DXF citit\n")
    except Exception as e:
        print(f"❌ Eroare citire: {e}")
        exit(1)

    # Citire date
    print("="*60)
    print("CITIRE DATE DXF")
    print("="*60)
    control_points = read_control_circles(doc, layer="control")
    contours = read_contours(doc, layer="IfcRoof")
    
    if not contours:
        print("❌ Nu s-au găsit contururi!")
        exit(1)

    vertices = associate_z(contours, control_points)

    # Construire acoperiș
    print("="*60)
    print("CONSTRUIRE ACOPERIȘ")
    print("="*60)
    roof_mesh = build_roof_mesh(vertices, thickness=THICKNESS)

    # Construire structură șarpantă
    print("="*60)
    print("CONSTRUIRE STRUCTURĂ ȘARPANTĂ")
    print("="*60)
    truss_mesh = build_truss_structure(vertices)

    # Combinare acoperiș + structură
    print("\n" + "="*60)
    print("COMBINARE FINALĂ")
    print("="*60)
    complete_mesh = trimesh.util.concatenate([roof_mesh, truss_mesh])
    
    print(f"✅ Mesh complet:")
    print(f"   - Vertices: {len(complete_mesh.vertices)}")
    print(f"   - Fețe: {len(complete_mesh.faces)}")
    print(f"   - Watertight: {complete_mesh.is_watertight}")

    # Vizualizare
    print("\n" + "="*60)
    print("VIZUALIZARE 3D")
    print("="*60)
    complete_mesh.show()

    # Export
    output_file = "roof_with_truss.obj"
    complete_mesh.export(output_file)
    print(f"\n✅ Exportat: {output_file}")
    
    print("\n" + "="*60)
    print("FINALIZAT!")
    print("="*60)