#!/usr/bin/env python3
"""
Creează un DXF de test cu poligoane inclinate pentru testarea funcționalității angle.
"""
import ezdxf

# Creează un document DXF nou
doc = ezdxf.new('R2010')
msp = doc.modelspace()

# Poligon cu unghi pozitiv (30 grade antiorar)
points1 = [(0, 0), (2, 0), (2, 1), (0, 1)]
poly1 = msp.add_lwpolyline(points1, close=True)
poly1.dxf.layer = "TestLayer1"

# Adaugă XDATA pentru primul poligon
poly1.set_xdata('QCAD', [
    (1000, "height:0.5"),
    (1000, "z:0.0"),
    (1000, "Name:PositiveAngle"),
    (1000, "solid:1"),
    (1000, "angle:30.0")  # 30 grade antiorar
])

# Poligon cu unghi negativ (-45 grade orar)
points2 = [(3, 0), (5, 0), (5, 1), (3, 1)]
poly2 = msp.add_lwpolyline(points2, close=True)
poly2.dxf.layer = "TestLayer2"

# Adaugă XDATA pentru al doilea poligon
poly2.set_xdata('QCAD', [
    (1000, "height:0.8"),
    (1000, "z:0.0"),
    (1000, "Name:NegativeAngle"),
    (1000, "solid:1"),
    (1000, "angle:-45.0")  # -45 grade orar
])

# Poligon fără unghi (orizontal)
points3 = [(6, 0), (8, 0), (8, 1), (6, 1)]
poly3 = msp.add_lwpolyline(points3, close=True)
poly3.dxf.layer = "TestLayer3"

# Adaugă XDATA pentru al treilea poligon (fără angle)
poly3.set_xdata('QCAD', [
    (1000, "height:0.3"),
    (1000, "z:0.0"),
    (1000, "Name:HorizontalPlane"),
    (1000, "solid:1")
])

# Cerc cu unghi
circle = msp.add_circle((0, 3), 0.5)
circle.dxf.layer = "CircleLayer"

# Adaugă XDATA pentru cerc
circle.set_xdata('QCAD', [
    (1000, "height:1.0"),
    (1000, "z:0.0"),
    (1000, "Name:InclinedCircle"),
    (1000, "solid:1"),
    (1000, "angle:60.0")  # 60 grade antiorar
])

# Salvează documentul
doc.saveas('test_inclined_polygons.dxf')
print("Created test_inclined_polygons.dxf with:")
print("- Rectangle with +30° angle (anticlockwise)")
print("- Rectangle with -45° angle (clockwise)")
print("- Rectangle with no angle (horizontal)")
print("- Circle with +60° angle (anticlockwise)")