#!/usr/bin/env python3
"""
Creează un DXF de test pentru funcționalitatea de rotație pe axele X și Y.
"""
import ezdxf

def create_xyz_rotation_test():
    # Creează un document DXF nou
    doc = ezdxf.new('R2010')
    msp = doc.modelspace()
    
    # 1. Poligon orizontal standard (referință)
    poly1_points = [(0, 0), (2, 0), (2, 1), (0, 1)]
    poly1 = msp.add_lwpolyline(poly1_points, close=True)
    poly1.dxf.layer = "TestLayer"
    poly1.set_xdata('QCAD', [
        (1000, "height:0.5"),
        (1000, "z:0.0"),
        (1000, "Name:HorizontalReference"),
        (1000, "solid:1")
    ])
    
    # 2. Poligon rotit cu 90° pe axa X (devine vertical în planul YZ)
    poly2_points = [(3, 0), (5, 0), (5, 1), (3, 1)]
    poly2 = msp.add_lwpolyline(poly2_points, close=True)
    poly2.dxf.layer = "TestLayer"
    poly2.set_xdata('QCAD', [
        (1000, "height:0.5"),
        (1000, "z:0.0"),
        (1000, "Name:RotatedX90"),
        (1000, "solid:1"),
        (1000, "rotate_x:90.0")  # Rotație 90° pe axa X
    ])
    
    # 3. Poligon rotit cu 90° pe axa Y (devine vertical în planul XZ)
    poly3_points = [(6, 0), (8, 0), (8, 1), (6, 1)]
    poly3 = msp.add_lwpolyline(poly3_points, close=True)
    poly3.dxf.layer = "TestLayer"
    poly3.set_xdata('QCAD', [
        (1000, "height:0.5"),
        (1000, "z:0.0"),
        (1000, "Name:RotatedY90"),
        (1000, "solid:1"),
        (1000, "rotate_y:90.0")  # Rotație 90° pe axa Y
    ])
    
    # 4. Poligon rotit cu 45° pe axa X
    poly4_points = [(0, 3), (2, 3), (2, 4), (0, 4)]
    poly4 = msp.add_lwpolyline(poly4_points, close=True)
    poly4.dxf.layer = "TestLayer"
    poly4.set_xdata('QCAD', [
        (1000, "height:0.5"),
        (1000, "z:0.0"),
        (1000, "Name:RotatedX45"),
        (1000, "solid:1"),
        (1000, "rotate_x:45.0")  # Rotație 45° pe axa X
    ])
    
    # 5. Poligon rotit cu 45° pe axa Y
    poly5_points = [(3, 3), (5, 3), (5, 4), (3, 4)]
    poly5 = msp.add_lwpolyline(poly5_points, close=True)
    poly5.dxf.layer = "TestLayer"
    poly5.set_xdata('QCAD', [
        (1000, "height:0.5"),
        (1000, "z:0.0"),
        (1000, "Name:RotatedY45"),
        (1000, "solid:1"),
        (1000, "rotate_y:45.0")  # Rotație 45° pe axa Y
    ])
    
    # 6. Poligon cu rotații combinate (X și Y)
    poly6_points = [(6, 3), (8, 3), (8, 4), (6, 4)]
    poly6 = msp.add_lwpolyline(poly6_points, close=True)
    poly6.dxf.layer = "TestLayer"
    poly6.set_xdata('QCAD', [
        (1000, "height:0.5"),
        (1000, "z:0.0"),
        (1000, "Name:RotatedXY"),
        (1000, "solid:1"),
        (1000, "rotate_x:30.0"),  # Rotație 30° pe axa X
        (1000, "rotate_y:60.0")   # Rotație 60° pe axa Y
    ])
    
    # 7. Poligon cu toate tipurile de rotații (angle + rotate_x + rotate_y)
    poly7_points = [(9, 1), (11, 1), (11, 2), (9, 2)]
    poly7 = msp.add_lwpolyline(poly7_points, close=True)
    poly7.dxf.layer = "TestLayer"
    poly7.set_xdata('QCAD', [
        (1000, "height:0.5"),
        (1000, "z:0.0"),
        (1000, "Name:AllRotations"),
        (1000, "solid:1"),
        (1000, "angle:15.0"),     # Rotația planului înclinat
        (1000, "rotate_x:30.0"),  # Rotație pe axa X
        (1000, "rotate_y:45.0")   # Rotație pe axa Y
    ])
    
    # 8. Cerc cu rotație pe axa X (devine elipsă în proiecție)
    circle = msp.add_circle((0, 6), 0.5)
    circle.dxf.layer = "TestLayer"
    circle.set_xdata('QCAD', [
        (1000, "height:0.3"),
        (1000, "z:0.0"),
        (1000, "Name:RotatedCircle"),
        (1000, "solid:1"),
        (1000, "rotate_x:90.0")  # Cerc vertical
    ])
    
    # 9. Poligon cu rotații negative
    poly9_points = [(3, 6), (5, 6), (5, 7), (3, 7)]
    poly9 = msp.add_lwpolyline(poly9_points, close=True)
    poly9.dxf.layer = "TestLayer"
    poly9.set_xdata('QCAD', [
        (1000, "height:0.5"),
        (1000, "z:0.0"),
        (1000, "Name:NegativeRotations"),
        (1000, "solid:1"),
        (1000, "rotate_x:-45.0"),  # Rotație negativă pe X
        (1000, "rotate_y:-30.0")   # Rotație negativă pe Y
    ])
    
    # Salvează documentul
    doc.saveas('xyz_rotation_test.dxf')
    print("Created xyz_rotation_test.dxf with:")
    print("- Horizontal reference polygon")
    print("- X-axis rotation: 90° (vertical in YZ plane)")
    print("- Y-axis rotation: 90° (vertical in XZ plane)")
    print("- X-axis rotation: 45° (tilted)")
    print("- Y-axis rotation: 45° (tilted)")
    print("- Combined X+Y rotations")
    print("- All rotation types combined (angle + rotate_x + rotate_y)")
    print("- Rotated circle (becomes elliptical in projection)")
    print("- Negative rotations")

if __name__ == "__main__":
    create_xyz_rotation_test()