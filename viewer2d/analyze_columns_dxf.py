#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""
Script pentru a analiza XDATA din DXF pentru coloanele problematice
"""

import ezdxf
import sys
import os

def analyze_column_xdata():
    """Analizează valorile XDATA pentru toate elementele cu 'column' în nume"""
    
    dxf_file = 'python/dxf/0First_floor.dxf'
    if not os.path.exists(dxf_file):
        print(f"Fișierul DXF {dxf_file} nu există")
        return
    
    try:
        doc = ezdxf.readfile(dxf_file)
        msp = doc.modelspace()
        
        print("=== Analiza XDATA pentru Coloane din 0First_floor.dxf ===")
        print("-" * 80)
        
        # Caută toate entitățile cu XDATA care conține "column" în Name
        column_entities = []
        all_entities_with_xdata = []
        
        for entity in msp:
            xdata = getattr(entity, 'xdata', None)
            if xdata:
                qcad_data = xdata.get("QCAD") if "QCAD" in xdata else []
                name_found = None
                for code, value in qcad_data:
                    if code == 1000:
                        sval = str(value)
                        if sval.startswith("Name:"):
                            name_found = sval.split(":", 1)[1].strip()
                            break
                
                all_entities_with_xdata.append((entity, name_found))
                
                if name_found and 'column' in name_found.lower():
                    column_entities.append((entity, name_found))
        
        print(f"Total entități cu XDATA: {len(all_entities_with_xdata)}")
        print(f"Entități cu 'column' în Name: {len(column_entities)}")
        print()
        
        if not column_entities:
            print("Nu s-au găsit entități cu 'column' în Name. Să verific toate entitățile...")
            # Afișează primele 10 entități cu XDATA pentru debugging
            for i, (entity, name) in enumerate(all_entities_with_xdata[:10]):
                print(f"Entitate {i+1}: {entity.dxftype()} - Name: '{name}' - Layer: {getattr(entity.dxf, 'layer', 'unknown')}")
            print()
            return
        
        # Analizează fiecare coloană găsită
        for i, (entity, name) in enumerate(column_entities):
            print(f"=== COLOANA {i+1}: {name} ===")
            print(f"Tip entitate: {entity.dxftype()}")
            print(f"Layer: {getattr(entity.dxf, 'layer', 'unknown')}")
            print(f"Handle: {getattr(entity, 'handle', 'unknown')}")
            
            # Analizează toate valorile XDATA
            xdata = getattr(entity, 'xdata', None)
            if xdata:
                qcad_data = xdata.get("QCAD") if "QCAD" in xdata else []
                print("XDATA QCAD:")
                
                for code, value in qcad_data:
                    if code == 1000:
                        sval = str(value)
                        print(f"  {sval}")
                        
                        # Parsează valorile importante
                        if sval.startswith("z:"):
                            z_val = sval.split(":", 1)[1].strip()
                            print(f"    ⚠️  Z GĂSIT: {z_val}")
                        elif sval.startswith("height:"):
                            height_val = sval.split(":", 1)[1].strip()
                            print(f"    📏 Height: {height_val}")
                        elif sval.startswith("Name:"):
                            name_val = sval.split(":", 1)[1].strip()
                            print(f"    🏷️  Name: {name_val}")
            
            # Verifică dacă este în bloc
            if entity.dxftype() == 'INSERT':
                block_name = getattr(entity.dxf, 'name', 'unknown')
                insert_point = getattr(entity.dxf, 'insert', None)
                print(f"INSERT Block: {block_name}")
                if insert_point:
                    print(f"Insert Point: ({insert_point.x:.3f}, {insert_point.y:.3f}, {insert_point.z:.3f})")
                
                # Verifică blocul
                if block_name in doc.blocks:
                    block = doc.blocks[block_name]
                    print(f"Entități în bloc: {len(list(block))}")
                    
                    for j, block_entity in enumerate(block):
                        block_xdata = getattr(block_entity, 'xdata', None)
                        if block_xdata:
                            block_qcad_data = block_xdata.get("QCAD") if "QCAD" in block_xdata else []
                            if block_qcad_data:
                                print(f"  Entitate bloc {j+1} ({block_entity.dxftype()}):")
                                for code, value in block_qcad_data:
                                    if code == 1000:
                                        sval = str(value)
                                        print(f"    {sval}")
            
            print()
            
        # Caută și entitățile de pe layer-uri cu "Column" în nume
        print("\n=== VERIFICARE LAYER-URI CU 'COLUMN' ===")
        column_layers = set()
        for entity in msp:
            layer = getattr(entity.dxf, 'layer', '')
            if 'column' in layer.lower() or 'Column' in layer:
                column_layers.add(layer)
        
        if column_layers:
            print(f"Layer-uri cu 'column' găsite: {column_layers}")
            
            for layer in column_layers:
                print(f"\n--- Entități pe layer {layer} ---")
                layer_entities = [e for e in msp if getattr(e.dxf, 'layer', '') == layer]
                
                for entity in layer_entities[:3]:  # Primele 3
                    print(f"{entity.dxftype()} - Handle: {getattr(entity, 'handle', 'unknown')}")
                    
                    xdata = getattr(entity, 'xdata', None)
                    if xdata:
                        qcad_data = xdata.get("QCAD") if "QCAD" in xdata else []
                        for code, value in qcad_data:
                            if code == 1000:
                                sval = str(value)
                                if sval.startswith(("z:", "height:", "Name:")):
                                    print(f"  {sval}")
        else:
            print("Nu s-au găsit layer-uri cu 'column' în nume")
            
    except Exception as e:
        print(f"Eroare la citirea DXF: {e}")
        import traceback
        traceback.print_exc()

if __name__ == "__main__":
    analyze_column_xdata()