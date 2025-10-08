#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""
Script pentru a verifica valorile XDATA z: și height: din DXF pentru coloane
"""

import ezdxf
import sys
import os

def debug_column_xdata():
    """Verifică valorile XDATA pentru coloane din DXF"""
    
    # Lista fișierelor DXF de verificat
    dxf_files = ['ifcspace_xdata_test.dxf', 'test_ifc_layers.dxf', 'ifc_composite_test.dxf']
    
    for dxf_file in dxf_files:
        if not os.path.exists(dxf_file):
            print(f"Fișierul DXF {dxf_file} nu există")
            continue
        
        print(f"\n=== Analiza XDATA pentru Coloane în {dxf_file} ===")
        print("-" * 60)
        
        try:
            doc = ezdxf.readfile(dxf_file)
            msp = doc.modelspace()
            
            # Caută INSERT-uri cu layer care conține "Column"
            column_inserts = []
            all_inserts = []
            
            for entity in msp:
                if entity.dxftype() == 'INSERT':
                    layer = getattr(entity.dxf, 'layer', '')
                    all_inserts.append(layer)
                    if 'IfcColumn' in layer or 'column' in layer.lower() or 'Column' in layer:
                        column_inserts.append(entity)
            
            print(f"Total INSERT-uri: {len(all_inserts)}")
            print(f"Layere INSERT găsite: {set(all_inserts)}")
            print(f"INSERT-uri cu coloane: {len(column_inserts)}")
            print()
            
            for i, insert in enumerate(column_inserts):
                layer = getattr(insert.dxf, 'layer', 'unknown')
                handle = getattr(insert, 'handle', 'unknown')
                
                print(f"Coloana {i+1}: Layer={layer}, Handle={handle}")
                
                # Verifică XDATA pe INSERT
                xdata = getattr(insert, 'xdata', None)
                if xdata:
                    qcad_data = xdata.get("QCAD", [])
                    z_global = None
                    for code, value in qcad_data:
                        if code == 1000:
                            sval = str(value)
                            if sval.startswith("z:"):
                                try:
                                    z_global = float(sval.split(":")[1])
                                    print(f"  INSERT XDATA z: {z_global}")
                                except:
                                    pass
                
                # Verifică blocul și entitățile din bloc
                block_name = getattr(insert.dxf, 'name', 'unknown')
                print(f"  Block name: {block_name}")
                
                if block_name in doc.blocks:
                    block = doc.blocks[block_name]
                    print(f"  Entități în bloc: {len(list(block))}")
                    
                    for entity in block:
                        entity_type = entity.dxftype()
                        entity_layer = getattr(entity.dxf, 'layer', 'unknown')
                        
                        # Verifică XDATA pe entități
                        xdata = getattr(entity, 'xdata', None)
                        if xdata:
                            qcad_data = xdata.get("QCAD", [])
                            height = None
                            z_entity = None
                            name = None
                            
                            for code, value in qcad_data:
                                if code == 1000:
                                    sval = str(value)
                                    if sval.startswith("height:"):
                                        try:
                                            height = float(sval.split(":")[1])
                                        except:
                                            pass
                                    elif sval.startswith("z:"):
                                        try:
                                            z_entity = float(sval.split(":")[1])
                                        except:
                                            pass
                                    elif sval.startswith("Name:"):
                                        name = sval.split(":", 1)[1].strip()
                            
                            if height is not None or z_entity is not None or name:
                                print(f"    {entity_type} (layer: {entity_layer}):")
                                if name:
                                    print(f"      Name: {name}")
                                if height is not None:
                                    print(f"      height: {height}")
                                if z_entity is not None:
                                    print(f"      z: {z_entity}")
                print()
                
        except Exception as e:
            print(f"Eroare la citirea DXF {dxf_file}: {e}")
            continue

if __name__ == "__main__":
    debug_column_xdata()