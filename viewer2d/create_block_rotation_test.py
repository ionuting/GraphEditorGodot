#!/usr/bin/env python3
"""
Creează un DXF de test pentru funcționalitatea de rotație XYZ în blocuri.
"""
import ezdxf

def create_block_rotation_test():
    # Creează un document DXF nou
    doc = ezdxf.new('R2010')
    msp = doc.modelspace()
    
    # 1. Creează un bloc cu geometrie
    block = doc.blocks.new(name='TestGeometryBlock')
    
    # Adaugă un poligon în bloc cu XDATA pentru rotații
    poly_in_block = block.add_lwpolyline([(0, 0), (1, 0), (1, 0.5), (0, 0.5)], close=True)
    poly_in_block.set_xdata('QCAD', [
        (1000, "height:0.3"),
        (1000, "z:0.0"),
        (1000, "Name:BlockPolygon"),
        (1000, "solid:1"),
        (1000, "rotate_x:45.0")  # Rotația elementului din bloc
    ])
    
    # Adaugă un cerc în bloc
    circle_in_block = block.add_circle((2, 0.25), 0.25)
    circle_in_block.set_xdata('QCAD', [
        (1000, "height:0.4"),
        (1000, "z:0.0"),
        (1000, "Name:BlockCircle"),
        (1000, "solid:1"),
        (1000, "rotate_y:90.0")  # Rotația elementului din bloc
    ])
    
    # 2. Inserează blocul cu rotații globale
    insert1 = msp.add_blockref('TestGeometryBlock', (0, 0))
    insert1.dxf.layer = "TestBlocks"
    insert1.set_xdata('QCAD', [
        (1000, "z:0.0"),
        (1000, "Name:BlockInstance1"),
        (1000, "rotate_x:0.0"),   # Fără rotație globală
        (1000, "rotate_y:0.0")
    ])
    
    # 3. Inserează blocul cu rotație globală pe axa X
    insert2 = msp.add_blockref('TestGeometryBlock', (5, 0))
    insert2.dxf.layer = "TestBlocks"
    insert2.set_xdata('QCAD', [
        (1000, "z:0.0"),
        (1000, "Name:BlockInstance2"),
        (1000, "rotate_x:90.0"),  # Rotație globală 90° pe X
        (1000, "rotate_y:0.0")
    ])
    
    # 4. Inserează blocul cu rotație globală pe axa Y
    insert3 = msp.add_blockref('TestGeometryBlock', (10, 0))
    insert3.dxf.layer = "TestBlocks"
    insert3.set_xdata('QCAD', [
        (1000, "z:0.0"),
        (1000, "Name:BlockInstance3"),
        (1000, "rotate_x:0.0"),
        (1000, "rotate_y:90.0")   # Rotație globală 90° pe Y
    ])
    
    # 5. Inserează blocul cu rotații globale combinate
    insert4 = msp.add_blockref('TestGeometryBlock', (0, 5))
    insert4.dxf.layer = "TestBlocks"
    insert4.set_xdata('QCAD', [
        (1000, "z:0.0"),
        (1000, "Name:BlockInstance4"),
        (1000, "rotate_x:30.0"),  # Rotație globală 30° pe X
        (1000, "rotate_y:45.0")   # Rotație globală 45° pe Y
    ])
    
    # 6. Inserează blocul cu rotație DXF standard + rotații XYZ
    insert5 = msp.add_blockref('TestGeometryBlock', (5, 5))
    insert5.dxf.layer = "TestBlocks"
    insert5.dxf.rotation = 45.0  # Rotația DXF standard în jurul axei Z
    insert5.set_xdata('QCAD', [
        (1000, "z:1.0"),          # Nivel ridicat
        (1000, "Name:BlockInstance5"),
        (1000, "rotate_x:45.0"),  # + rotație pe X
        (1000, "rotate_y:30.0")   # + rotație pe Y
    ])
    
    # 7. Creează un bloc mai complex cu mai multe elemente
    complex_block = doc.blocks.new(name='ComplexBlock')
    
    # Elementul 1: poligon cu rotația pe X
    poly1 = complex_block.add_lwpolyline([(0, 0), (0.5, 0), (0.5, 0.3), (0, 0.3)], close=True)
    poly1.set_xdata('QCAD', [
        (1000, "height:0.2"),
        (1000, "z:0.0"),
        (1000, "Name:ComplexElement1"),
        (1000, "solid:1"),
        (1000, "rotate_x:90.0")
    ])
    
    # Elementul 2: poligon cu rotația pe Y
    poly2 = complex_block.add_lwpolyline([(1, 0), (1.5, 0), (1.5, 0.3), (1, 0.3)], close=True)
    poly2.set_xdata('QCAD', [
        (1000, "height:0.2"),
        (1000, "z:0.0"),
        (1000, "Name:ComplexElement2"),
        (1000, "solid:1"),
        (1000, "rotate_y:90.0")
    ])
    
    # Elementul 3: void cu rotații combinate
    poly3 = complex_block.add_lwpolyline([(0.75, 0.6), (1.25, 0.6), (1.25, 0.9), (0.75, 0.9)], close=True)
    poly3.set_xdata('QCAD', [
        (1000, "height:0.15"),
        (1000, "z:0.1"),
        (1000, "Name:ComplexVoid"),
        (1000, "solid:0"),  # Void
        (1000, "rotate_x:45.0"),
        (1000, "rotate_y:45.0")
    ])
    
    # Inserează blocul complex
    insert_complex = msp.add_blockref('ComplexBlock', (10, 5))
    insert_complex.dxf.layer = "TestBlocks"
    insert_complex.set_xdata('QCAD', [
        (1000, "z:0.5"),
        (1000, "Name:ComplexBlockInstance"),
        (1000, "rotate_x:15.0"),  # Rotație globală pe X
        (1000, "rotate_y:30.0")   # Rotație globală pe Y
    ])
    
    # Salvează documentul
    doc.saveas('block_rotation_test.dxf')
    print("Created block_rotation_test.dxf with:")
    print("- TestGeometryBlock: simple block with polygon and circle")
    print("- Multiple instances with different global XYZ rotations")
    print("- Individual element rotations within blocks")
    print("- Combined DXF rotation + XYZ rotations")
    print("- ComplexBlock: multiple elements with individual rotations + global block rotations")
    print("- Void elements with rotations inside blocks")

if __name__ == "__main__":
    create_block_rotation_test()