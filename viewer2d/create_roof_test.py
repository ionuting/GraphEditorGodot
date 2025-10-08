#!/usr/bin/env python3
"""
Creează un DXF de test pentru funcționalitatea de tăiere la acoperiș.
"""
import ezdxf

# Creează un document DXF nou
doc = ezdxf.new('R2010')
msp = doc.modelspace()

# 1. Perete înalt care depășește acoperișul
wall_points = [(0, 0), (4, 0), (4, 0.2), (0, 0.2)]
wall = msp.add_lwpolyline(wall_points, close=True)
wall.dxf.layer = "IfcWall"
wall.set_xdata('QCAD', [
    (1000, "height:3.5"),  # Înălțime mare care va depăși acoperișul
    (1000, "z:0.0"),
    (1000, "Name:TallWall"),
    (1000, "solid:1")
])

# 2. Coloană înaltă care depășește acoperișul
column_points = [(5, 1), (5.3, 1), (5.3, 1.3), (5, 1.3)]
column = msp.add_lwpolyline(column_points, close=True)
column.dxf.layer = "IfcColumn"
column.set_xdata('QCAD', [
    (1000, "height:4.0"),  # Coloană foarte înaltă
    (1000, "z:0.0"),
    (1000, "Name:TallColumn"),
    (1000, "solid:1")
])

# 3. Acoperire (covering) care depășește
covering_points = [(6, 0), (8, 0), (8, 1), (6, 1)]
covering = msp.add_lwpolyline(covering_points, close=True)
covering.dxf.layer = "IfcCovering"
covering.set_xdata('QCAD', [
    (1000, "height:3.2"),
    (1000, "z:0.0"),
    (1000, "Name:TallCovering"),
    (1000, "solid:1")
])

# 4. Acoperiș înclinat la înălțime de 2.8m
roof_points = [(-1, -1), (9, -1), (9, 3), (-1, 3)]
roof = msp.add_lwpolyline(roof_points, close=True)
roof.dxf.layer = "IfcSlab"  # Layer pentru acoperiș
roof.set_xdata('QCAD', [
    (1000, "height:0.3"),  # Grosimea acoperișului
    (1000, "z:2.8"),       # Acoperiș începe la 2.8m
    (1000, "Name:RoofSlab"),
    (1000, "solid:1"),
    (1000, "angle:15.0")   # Acoperiș înclinat cu 15 grade
])

# 5. Al doilea acoperiș la înălțime diferită (pentru a testa intersecții multiple)
roof2_points = [(10, 0), (12, 0), (12, 2), (10, 2)]
roof2 = msp.add_lwpolyline(roof2_points, close=True)
roof2.dxf.layer = "Roof"  # Alt tip de layer pentru acoperiș
roof2.set_xdata('QCAD', [
    (1000, "height:0.2"),
    (1000, "z:2.5"),       # Acoperiș mai jos la 2.5m
    (1000, "Name:LowerRoof"),
    (1000, "solid:1")
])

# 6. Perete scurt care NU depășește acoperișul (nu trebuie tăiat)
short_wall_points = [(1, 5), (3, 5), (3, 5.2), (1, 5.2)]
short_wall = msp.add_lwpolyline(short_wall_points, close=True)
short_wall.dxf.layer = "IfcWall"
short_wall.set_xdata('QCAD', [
    (1000, "height:2.0"),  # Înălțime mică, sub acoperiș
    (1000, "z:0.0"),
    (1000, "Name:ShortWall"),
    (1000, "solid:1")
])

# 7. Element pe alt layer (nu trebuie tăiat)
other_element_points = [(0, 6), (2, 6), (2, 7), (0, 7)]
other_element = msp.add_lwpolyline(other_element_points, close=True)
other_element.dxf.layer = "OtherLayer"
other_element.set_xdata('QCAD', [
    (1000, "height:4.0"),  # Înalt dar nu pe layer structural
    (1000, "z:0.0"),
    (1000, "Name:OtherElement"),
    (1000, "solid:1")
])

# Salvează documentul
doc.saveas('test_roof_trimming.dxf')
print("Created test_roof_trimming.dxf with:")
print("- Tall wall (3.5m) on IfcWall layer - should be trimmed")
print("- Tall column (4.0m) on IfcColumn layer - should be trimmed") 
print("- Tall covering (3.2m) on IfcCovering layer - should be trimmed")
print("- Inclined roof slab at 2.8m height")
print("- Lower roof at 2.5m height")
print("- Short wall (2.0m) - should NOT be trimmed")
print("- Other element (4.0m) on different layer - should NOT be trimmed")