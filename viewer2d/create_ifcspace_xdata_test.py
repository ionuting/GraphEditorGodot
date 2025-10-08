"""
Creează un test DXF cu IfcSpace care include XDATA Opening_area
pentru a testa noul GLB Converter cu calculele de suprafață
"""

import ezdxf
from ezdxf import units

def create_ifcspace_test_with_xdata():
    # Creează documentul DXF
    doc = ezdxf.new('R2010', setup=True)
    doc.units = units.M  # metri
    
    # Adaugă aplicația QCAD pentru XDATA
    doc.appids.new('QCAD')
    
    # Obține spațiul model
    msp = doc.modelspace()
    
    # Layer pentru IfcSpace
    doc.layers.new('IfcSpace', dxfattribs={'color': 7})
    
    # Creează un poligon pentru IfcSpace (cameră de 4x3 metri)
    space_points = [
        (0, 0),
        (4, 0),  
        (4, 3),
        (0, 3),
        (0, 0)  # închide poligonul
    ]
    
    # Adaugă poligonul ca LWPOLYLINE
    polyline = msp.add_lwpolyline(space_points, dxfattribs={'layer': 'IfcSpace'})
    
    # Adaugă geometrie 3D simplă pentru spațiu (box 4x3x2.8m)
    # Creează fețele pentru un box direct ca 3DFACE entities
    
    # Definește vârfurile boxului
    x, y, z = 4, 3, 2.8
    vertices = [
        (0, 0, 0), (x, 0, 0), (x, y, 0), (0, y, 0),  # bottom
        (0, 0, z), (x, 0, z), (x, y, z), (0, y, z)   # top
    ]
    
    # Definește fețele (indices în lista de vertices)
    faces = [
        [0, 1, 2, 3],  # bottom
        [4, 7, 6, 5],  # top
        [0, 4, 5, 1],  # front
        [2, 6, 7, 3],  # back
        [0, 3, 7, 4],  # left
        [1, 5, 6, 2]   # right
    ]
    
    # Adaugă fețele ca 3DFACE
    for face_indices in faces:
        face_vertices = [vertices[i] for i in face_indices]
        msp.add_3dface(face_vertices, dxfattribs={'layer': 'IfcSpace'})
    
    # Adaugă XDATA cu Opening_area pentru calculul suprafeței laterale
    polyline.set_xdata('QCAD', [
        (1000, 'z:2.8'),  # înălțimea camerei
        (1000, 'rotate_x:0.0'),
        (1000, 'rotate_y:0.0'),
        (1000, 'Opening_area:=1.2*2.1+0.8*1.5')  # ferestre + ușă
    ])
    
    # Salvează fișierul
    filename = 'ifcspace_xdata_test.dxf'
    doc.saveas(filename)
    print(f"✅ Created: {filename}")
    print("   - IfcSpace room: 4x3m with height 2.8m")
    print("   - XDATA Opening_area: =1.2*2.1+0.8*1.5 (should calculate to 3.72 m²)")
    print("   - Expected lateral_area: (4+3+4+3)*2.8 - 3.72 = 39.2 - 3.72 = 35.48 m²")
    
    return filename

if __name__ == "__main__":
    create_ifcspace_test_with_xdata()