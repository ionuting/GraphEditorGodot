#!/usr/bin/env python3
"""
Test comprehensiv pentru funcționalitatea angle cu diverse cazuri.
"""
import ezdxf

# Creează un document DXF nou
doc = ezdxf.new('R2010')
msp = doc.modelspace()

# Test 1: Unghi mic pozitiv (15 grade)
points1 = [(0, 0), (3, 0), (3, 2), (0, 2)]
poly1 = msp.add_lwpolyline(points1, close=True)
poly1.dxf.layer = "SmallPositive"
poly1.set_xdata('QCAD', [
    (1000, "height:1.0"),
    (1000, "z:0.0"),
    (1000, "Name:Small15Degrees"),
    (1000, "solid:1"),
    (1000, "angle:15.0")
])

# Test 2: Unghi mare negativ (-60 grade)
points2 = [(5, 0), (8, 0), (8, 1), (5, 1)]
poly2 = msp.add_lwpolyline(points2, close=True)
poly2.dxf.layer = "LargeNegative"
poly2.set_xdata('QCAD', [
    (1000, "height:0.8"),
    (1000, "z:1.0"),
    (1000, "Name:Large60DegreesNeg"),
    (1000, "solid:1"),
    (1000, "angle:-60.0")
])

# Test 3: Unghi de 90 grade (vertical)
points3 = [(10, 0), (12, 0), (12, 0.5), (10, 0.5)]
poly3 = msp.add_lwpolyline(points3, close=True)
poly3.dxf.layer = "Vertical"
poly3.set_xdata('QCAD', [
    (1000, "height:2.0"),
    (1000, "z:0.0"),
    (1000, "Name:Vertical90Degrees"),
    (1000, "solid:1"),
    (1000, "angle:90.0")
])

# Test 4: Unghi de -90 grade (vertical opus)
points4 = [(14, 0), (16, 0), (16, 0.5), (14, 0.5)]
poly4 = msp.add_lwpolyline(points4, close=True)
poly4.dxf.layer = "VerticalOpp"
poly4.set_xdata('QCAD', [
    (1000, "height:1.5"),
    (1000, "z:0.5"),
    (1000, "Name:VerticalMinus90"),
    (1000, "solid:1"),
    (1000, "angle:-90.0")
])

# Test 5: Triunghi cu unghi
points5 = [(0, 5), (2, 5), (1, 7)]
poly5 = msp.add_lwpolyline(points5, close=True)
poly5.dxf.layer = "Triangle"
poly5.set_xdata('QCAD', [
    (1000, "height:0.6"),
    (1000, "z:0.0"),
    (1000, "Name:InclinedTriangle"),
    (1000, "solid:1"),
    (1000, "angle:45.0")
])

# Test 6: Poligon complex cu unghi
points6 = [(5, 5), (7, 5), (8, 6), (7, 7), (5, 7), (4, 6)]
poly6 = msp.add_lwpolyline(points6, close=True)
poly6.dxf.layer = "Complex"
poly6.set_xdata('QCAD', [
    (1000, "height:1.2"),
    (1000, "z:0.0"),
    (1000, "Name:ComplexPolygon"),
    (1000, "solid:1"),
    (1000, "angle:30.0")
])

# Test 7: Void cu unghi (pentru testarea boolean operations)
points7 = [(1, 1), (2, 1), (2, 1.5), (1, 1.5)]
poly7 = msp.add_lwpolyline(points7, close=True)
poly7.dxf.layer = "VoidTest"
poly7.set_xdata('QCAD', [
    (1000, "height:2.0"),
    (1000, "z:0.0"),
    (1000, "Name:InclinedVoid"),
    (1000, "solid:0"),  # Void
    (1000, "angle:15.0")
])

# Salvează documentul
doc.saveas('comprehensive_angle_test.dxf')
print("Created comprehensive_angle_test.dxf with:")
print("- Small positive angle (15°)")
print("- Large negative angle (-60°)")  
print("- Vertical plane (90°)")
print("- Opposite vertical (-90°)") 
print("- Inclined triangle (45°)")
print("- Complex polygon (30°)")
print("- Inclined void (15°) for boolean testing")