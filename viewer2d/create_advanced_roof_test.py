#!/usr/bin/env python3
"""
Test avanzat pentru tăierea la acoperiș cu cazuri complexe.
"""
import ezdxf

# Creează un document DXF nou
doc = ezdxf.new('R2010')
msp = doc.modelspace()

# 1. Perete care se intersectează cu acoperiș înclinat
wall1_points = [(0, 0), (5, 0), (5, 0.3), (0, 0.3)]
wall1 = msp.add_lwpolyline(wall1_points, close=True)
wall1.dxf.layer = "IfcWall"
wall1.set_xdata('QCAD', [
    (1000, "height:4.0"),
    (1000, "z:0.0"),
    (1000, "Name:WallUnderInclinedRoof"),
    (1000, "solid:1")
])

# 2. Acoperiș înclinat la 45 grade care începe de la 2.0m
roof1_points = [(-1, -1), (6, -1), (6, 2), (-1, 2)]
roof1 = msp.add_lwpolyline(roof1_points, close=True)
roof1.dxf.layer = "IfcSlab"
roof1.set_xdata('QCAD', [
    (1000, "height:0.2"),
    (1000, "z:2.0"),
    (1000, "Name:InclinedRoof45"),
    (1000, "solid:1"),
    (1000, "angle:45.0")
])

# 3. Coloană înaltă care trece prin mai multe acoperișuri
column1_points = [(7, 1), (7.4, 1), (7.4, 1.4), (7, 1.4)]
column1 = msp.add_lwpolyline(column1_points, close=True)
column1.dxf.layer = "IfcColumn" 
column1.set_xdata('QCAD', [
    (1000, "height:6.0"),
    (1000, "z:0.0"),
    (1000, "Name:MultiRoofColumn"),
    (1000, "solid:1")
])

# 4. Primul acoperiș care taie coloana la 3.0m
roof2_points = [(6.5, 0.5), (8, 0.5), (8, 2), (6.5, 2)]
roof2 = msp.add_lwpolyline(roof2_points, close=True)
roof2.dxf.layer = "Roof"
roof2.set_xdata('QCAD', [
    (1000, "height:0.15"),
    (1000, "z:3.0"),
    (1000, "Name:FirstRoofLevel"),
    (1000, "solid:1")
])

# 5. Al doilea acoperiș mai sus care ar tăia coloana la 4.5m
roof3_points = [(6.5, 0.5), (8, 0.5), (8, 2), (6.5, 2)]
roof3 = msp.add_lwpolyline(roof3_points, close=True)
roof3.dxf.layer = "IfcSlab"
roof3.set_xdata('QCAD', [
    (1000, "height:0.1"),
    (1000, "z:4.5"),
    (1000, "Name:SecondRoofLevel"),
    (1000, "solid:1")
])

# 6. Perete scurt care nu se intersectează cu niciun acoperiș
wall2_points = [(10, 5), (12, 5), (12, 5.2), (10, 5.2)]
wall2 = msp.add_lwpolyline(wall2_points, close=True)
wall2.dxf.layer = "IfcWall"
wall2.set_xdata('QCAD', [
    (1000, "height:1.5"),
    (1000, "z:0.0"),
    (1000, "Name:IsolatedWall"),
    (1000, "solid:1")
])

# 7. Acoperiș foarte înclinat (80 grade - aproape vertical)
roof4_points = [(0, 5), (3, 5), (3, 6), (0, 6)]
roof4 = msp.add_lwpolyline(roof4_points, close=True)
roof4.dxf.layer = "Roof"
roof4.set_xdata('QCAD', [
    (1000, "height:0.05"),
    (1000, "z:2.2"),
    (1000, "Name:SteepRoof"),
    (1000, "solid:1"),
    (1000, "angle:80.0")
])

# 8. Perete sub acoperiș înclinat
wall3_points = [(1, 5.2), (2, 5.2), (2, 5.4), (1, 5.4)]
wall3 = msp.add_lwpolyline(wall3_points, close=True)
wall3.dxf.layer = "IfcWall"
wall3.set_xdata('QCAD', [
    (1000, "height:3.0"),
    (1000, "z:0.0"),
    (1000, "Name:WallUnderSteepRoof"),
    (1000, "solid:1")
])

# Salvează documentul
doc.saveas('advanced_roof_test.dxf')
print("Created advanced_roof_test.dxf with:")
print("- Wall under 45° inclined roof")
print("- Column intersecting multiple roof levels")
print("- Isolated wall (no intersection)")
print("- Wall under very steep roof (80°)")
print("- Multiple roof elements at different heights and angles")