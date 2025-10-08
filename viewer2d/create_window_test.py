#!/usr/bin/env python3
"""
Creează un DXF de test cu blocuri de ferestre pentru testarea încărcării GLTF.
"""
import ezdxf

def create_window_test_dxf():
    # Creează un document DXF nou
    doc = ezdxf.new('R2010')
    msp = doc.modelspace()
    
    # Creează definiția blocului pentru fereastră (chiar dacă nu avem geometria)
    # Acesta este necesar pentru a putea insera blocul
    block_def = doc.blocks.new(name="window120120")
    # Adaugă o geometrie simplă în bloc (va fi înlocuită cu GLTF în Godot)
    block_def.add_line(start=(0, 0), end=(1.2, 0))
    block_def.add_line(start=(1.2, 0), end=(1.2, 1.2))
    block_def.add_line(start=(1.2, 1.2), end=(0, 1.2))
    block_def.add_line(start=(0, 1.2), end=(0, 0))
    
    # 1. Fereastră pe peretele din față (fără rotație)
    window1 = msp.add_blockref("window120120", (2, 0), dxfattribs={"layer": "IfcWindow"})
    window1.set_xdata('QCAD', [
        (1000, "z:1.0"),  # Înălțimea ferestrei de la sol
        (1000, "height:1.2"),  # Înălțimea ferestrei
        (1000, "Name:FrontWindow")
    ])
    
    # 2. Fereastră pe peretele din dreapta (rotație 90°)
    window2 = msp.add_blockref("window120120", (5, 2), dxfattribs={
        "layer": "IfcWindow",
        "rotation": 90.0  # Rotație în grade
    })
    window2.set_xdata('QCAD', [
        (1000, "z:1.0"),
        (1000, "height:1.2"),
        (1000, "Name:RightWindow")
    ])
    
    # 3. Fereastră pe peretele din spate (rotație 180°)
    window3 = msp.add_blockref("window120120", (2, 4), dxfattribs={
        "layer": "IfcWindow", 
        "rotation": 180.0
    })
    window3.set_xdata('QCAD', [
        (1000, "z:0.8"),  # Fereastră mai jos
        (1000, "height:1.2"),
        (1000, "Name:BackWindow")
    ])
    
    # 4. Fereastră pe peretele din stânga (rotație 270°/-90°)
    window4 = msp.add_blockref("window120120", (0, 2), dxfattribs={
        "layer": "IfcWindow",
        "rotation": 270.0
    })
    window4.set_xdata('QCAD', [
        (1000, "z:1.2"),  # Fereastră mai sus
        (1000, "height:1.2"), 
        (1000, "Name:LeftWindow")
    ])
    
    # 5. Fereastră cu rotație nestandard (45°)
    window5 = msp.add_blockref("window120120", (6, 6), dxfattribs={
        "layer": "IfcWindow",
        "rotation": 45.0
    })
    window5.set_xdata('QCAD', [
        (1000, "z:1.5"),
        (1000, "height:1.2"),
        (1000, "Name:DiagonalWindow")
    ])
    
    # Adaugă și niște geometrie de referință (pereți)
    # Peretele din față
    front_wall_points = [(0, 0), (5, 0), (5, 0.2), (0, 0.2)]
    front_wall = msp.add_lwpolyline(front_wall_points, close=True)
    front_wall.dxf.layer = "IfcWall"
    front_wall.set_xdata('QCAD', [
        (1000, "height:3.0"),
        (1000, "z:0.0"),
        (1000, "Name:FrontWall"),
        (1000, "solid:1")
    ])
    
    # Peretele din dreapta
    right_wall_points = [(5, 0), (5.2, 0), (5.2, 4), (5, 4)]
    right_wall = msp.add_lwpolyline(right_wall_points, close=True)
    right_wall.dxf.layer = "IfcWall"
    right_wall.set_xdata('QCAD', [
        (1000, "height:3.0"),
        (1000, "z:0.0"),
        (1000, "Name:RightWall"),
        (1000, "solid:1")
    ])
    
    # Salvează documentul
    doc.saveas('window_blocks_test.dxf')
    print("Created window_blocks_test.dxf with:")
    print("- 5 window blocks on IfcWindow layer with different rotations")
    print("- Each window has position (x,y), z-height, and rotation angle")
    print("- Reference walls for context")
    print("- Window block name: 'window120120' maps to window120120.gltf")

if __name__ == "__main__":
    create_window_test_dxf()