#!/usr/bin/env python3
"""
Test simplu pentru a verifica poziționarea și rotația blocurilor.
"""
import ezdxf

def create_simple_positioning_test():
    # Creează un document DXF nou
    doc = ezdxf.new('R2010')
    msp = doc.modelspace()
    
    # Creează un bloc simplu
    block = doc.blocks.new(name='SimpleRect')
    
    # Un simplu pătrat de 1x1
    rect = block.add_lwpolyline([(0, 0), (1, 0), (1, 1), (0, 1)], close=True)
    rect.dxf.layer = "wood"
    rect.set_xdata('QCAD', [
        (1000, "height:0.1"),
        (1000, "Name:TestRect"),
        (1000, "solid:1")
    ])
    
    # Inserează la originea (0,0) - fără rotație
    insert1 = msp.add_blockref('SimpleRect', (0, 0))
    insert1.dxf.layer = "IfcTest"
    insert1.set_xdata('QCAD', [
        (1000, "z:0.0"),
        (1000, "rotate_x:0.0"),
        (1000, "rotate_y:0.0")
    ])
    
    # Inserează la (3,0) - cu rotație pe X
    insert2 = msp.add_blockref('SimpleRect', (3, 0))
    insert2.dxf.layer = "IfcTest"
    insert2.set_xdata('QCAD', [
        (1000, "z:0.0"),
        (1000, "rotate_x:90.0"),  # Vertical
        (1000, "rotate_y:0.0")
    ])
    
    # Inserează la (6,0) - cu rotație pe Y
    insert3 = msp.add_blockref('SimpleRect', (6, 0))
    insert3.dxf.layer = "IfcTest"
    insert3.set_xdata('QCAD', [
        (1000, "z:0.0"),
        (1000, "rotate_x:0.0"),
        (1000, "rotate_y:90.0")   # Vertical în altă direcție
    ])
    
    # Inserează la (0,3) - Z ridicat
    insert4 = msp.add_blockref('SimpleRect', (0, 3))
    insert4.dxf.layer = "IfcTest"
    insert4.set_xdata('QCAD', [
        (1000, "z:2.0"),          # Ridicat
        (1000, "rotate_x:0.0"),
        (1000, "rotate_y:0.0")
    ])
    
    # Salvează documentul
    doc.saveas('simple_positioning_test.dxf')
    print("Created simple_positioning_test.dxf for verifying positioning and rotation")

if __name__ == "__main__":
    create_simple_positioning_test()