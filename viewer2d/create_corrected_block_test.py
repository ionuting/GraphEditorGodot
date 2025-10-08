#!/usr/bin/env python3
"""
Creează un DXF de test pentru noua structură de rotații XYZ în blocuri.
Parametri pe bloc: z, rotate_x, rotate_y, layer
Parametri pe elemente: height, solid, Name, angle
"""
import ezdxf

def create_corrected_block_test():
    # Creează un document DXF nou
    doc = ezdxf.new('R2010')
    msp = doc.modelspace()
    
    # 1. Creează un bloc cu geometrie (doar proprietăți geometrice pe elemente)
    block = doc.blocks.new(name='GeometryBlock')
    
    # Element 1: poligon cu proprietăți geometrice
    poly1 = block.add_lwpolyline([(0, 0), (1, 0), (1, 0.5), (0, 0.5)], close=True)
    poly1.set_xdata('QCAD', [
        (1000, "height:0.3"),      # Înălțimea extrudării
        (1000, "Name:Wall"),       # Numele elementului
        (1000, "solid:1")          # Solid
    ])
    
    # Element 2: cerc cu proprietăți geometrice diferite
    circle1 = block.add_circle((2, 0.25), 0.25)
    circle1.set_xdata('QCAD', [
        (1000, "height:0.4"),      # Înălțime diferită
        (1000, "Name:Column"),     # Nume diferit
        (1000, "solid:1")          # Solid
    ])
    
    # Element 3: void cu proprietăți geometrice
    poly2 = block.add_lwpolyline([(0.2, 0.1), (0.8, 0.1), (0.8, 0.4), (0.2, 0.4)], close=True)
    poly2.set_xdata('QCAD', [
        (1000, "height:0.25"),     # Înălțime void
        (1000, "Name:Opening"),    # Nume void
        (1000, "solid:0")          # Void
    ])
    
    # Element 4: poligon cu plan înclinat
    poly3 = block.add_lwpolyline([(3, 0), (4, 0), (4, 0.5), (3, 0.5)], close=True)
    poly3.set_xdata('QCAD', [
        (1000, "height:0.6"),      # Înălțime
        (1000, "Name:Roof"),       # Nume
        (1000, "solid:1"),         # Solid
        (1000, "angle:30.0")       # Plan înclinat
    ])
    
    # 2. Inserează blocul fără rotații (referință)
    insert1 = msp.add_blockref('GeometryBlock', (0, 0))
    insert1.dxf.layer = "StructuralElements"  # Layer pentru material
    insert1.set_xdata('QCAD', [
        (1000, "z:0.0"),           # Poziția Z a blocului
        (1000, "rotate_x:0.0"),    # Fără rotație X
        (1000, "rotate_y:0.0")     # Fără rotație Y
    ])
    
    # 3. Inserează blocul cu rotație pe X (vertical în planul YZ)
    insert2 = msp.add_blockref('GeometryBlock', (6, 0))
    insert2.dxf.layer = "StructuralElements"
    insert2.set_xdata('QCAD', [
        (1000, "z:0.0"),
        (1000, "rotate_x:90.0"),   # Rotție 90° pe X
        (1000, "rotate_y:0.0")
    ])
    
    # 4. Inserează blocul cu rotație pe Y (vertical în planul XZ)
    insert3 = msp.add_blockref('GeometryBlock', (12, 0))
    insert3.dxf.layer = "StructuralElements"
    insert3.set_xdata('QCAD', [
        (1000, "z:0.0"),
        (1000, "rotate_x:0.0"),
        (1000, "rotate_y:90.0")    # Rotație 90° pe Y
    ])
    
    # 5. Inserează blocul cu rotații combinate și Z ridicat
    insert4 = msp.add_blockref('GeometryBlock', (0, 6))
    insert4.dxf.layer = "StructuralElements"
    insert4.set_xdata('QCAD', [
        (1000, "z:2.0"),           # Poziție Z ridicată
        (1000, "rotate_x:45.0"),   # Rotație 45° pe X
        (1000, "rotate_y:30.0")    # Rotație 30° pe Y
    ])
    
    # 6. Inserează blocul cu layer diferit (material diferit)
    insert5 = msp.add_blockref('GeometryBlock', (6, 6))
    insert5.dxf.layer = "ConcreteElements"  # Layer diferit
    insert5.set_xdata('QCAD', [
        (1000, "z:1.0"),
        (1000, "rotate_x:0.0"),
        (1000, "rotate_y:45.0")
    ])
    
    # 7. Inserează blocul cu rotație DXF + rotații XYZ
    insert6 = msp.add_blockref('GeometryBlock', (12, 6))
    insert6.dxf.layer = "SteelElements"
    insert6.dxf.rotation = 45.0           # Rotația DXF în jurul Z
    insert6.set_xdata('QCAD', [
        (1000, "z:1.5"),
        (1000, "rotate_x:30.0"),
        (1000, "rotate_y:60.0")
    ])
    
    # 8. Creează un bloc mai simplu pentru testare
    simple_block = doc.blocks.new(name='SimpleBlock')
    
    # Un singur element simplu
    simple_poly = simple_block.add_lwpolyline([(0, 0), (0.5, 0), (0.5, 0.5), (0, 0.5)], close=True)
    simple_poly.set_xdata('QCAD', [
        (1000, "height:0.2"),
        (1000, "Name:SimpleElement"),
        (1000, "solid:1")
    ])
    
    # Inserează blocul simplu cu rotații extreme
    insert_simple = msp.add_blockref('SimpleBlock', (18, 3))
    insert_simple.dxf.layer = "TestElements"
    insert_simple.set_xdata('QCAD', [
        (1000, "z:0.5"),
        (1000, "rotate_x:90.0"),   # Vertical pe X
        (1000, "rotate_y:90.0")    # + Vertical pe Y
    ])
    
    # Salvează documentul
    doc.saveas('corrected_block_test.dxf')
    print("Created corrected_block_test.dxf with:")
    print("- Block parameters: z, rotate_x, rotate_y (on INSERT)")
    print("- Element parameters: height, solid, Name, angle (on geometry in block)")
    print("- Layer on INSERT for material mapping")
    print("- World position from INSERT coordinates")
    print("- Multiple test cases with different rotations and materials")

if __name__ == "__main__":
    create_corrected_block_test()