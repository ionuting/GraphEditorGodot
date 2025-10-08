#!/usr/bin/env python3
"""
Test pentru IFC Space Exporter
Creează date de test și testează funcționalitatea de export
"""

import json
import os
import sys
from ifc_space_exporter import export_spaces_to_ifc

def create_test_data():
    """Creează date de test pentru IFC export"""
    
    # Date geometrice simulate din Godot
    godot_data = {
        "spaces": [
            {
                "mesh_name": "IfcSpace_wall_Office1_1",
                "uuid": "12345678-1234-1234-1234-123456789001",
                "vertices": [
                    [0.0, 0.0, 0.0],
                    [5.0, 0.0, 0.0],
                    [5.0, 4.0, 0.0],
                    [0.0, 4.0, 0.0]
                ],
                "vertex_count": 4,
                "height": 2.8
            },
            {
                "mesh_name": "IfcSpace_wall_Conference1_1",
                "uuid": "12345678-1234-1234-1234-123456789002",
                "vertices": [
                    [6.0, 0.0, 0.0],
                    [10.0, 0.0, 0.0],
                    [10.0, 6.0, 0.0],
                    [6.0, 6.0, 0.0]
                ],
                "vertex_count": 4,
                "height": 3.2
            }
        ],
        "export_timestamp": 1696672800.0
    }
    
    # Date de mapping simulate
    mapping_data = [
        {
            "dxf_handle": "1A2B",
            "mesh_name": "IfcSpace_wall_Office1_1",
            "uuid": "12345678-1234-1234-1234-123456789001",
            "layer": "IfcSpace",
            "area": 20.0,
            "perimeter": 18.0,
            "lateral_area": 47.2,  # Calculat cu Opening_area formula
            "volume": 56.0,
            "height": 2.8,
            "vertices": [
                [0.0, 0.0],
                [5.0, 0.0],
                [5.0, 4.0],
                [0.0, 4.0]
            ]
        },
        {
            "dxf_handle": "3C4D",
            "mesh_name": "IfcSpace_wall_Conference1_1",
            "uuid": "12345678-1234-1234-1234-123456789002",
            "layer": "IfcSpace",
            "area": 24.0,
            "perimeter": 20.0,
            "lateral_area": 60.5,  # Calculat cu Opening_area formula
            "volume": 76.8,
            "height": 3.2,
            "vertices": [
                [6.0, 0.0],
                [10.0, 0.0],
                [10.0, 6.0],
                [6.0, 6.0]
            ]
        },
        {
            "dxf_handle": "5E6F",
            "mesh_name": "IfcWall_concrete_Wall1_1",
            "uuid": "12345678-1234-1234-1234-123456789003",
            "layer": "IfcWall",
            "area": 15.0,
            "perimeter": 12.0,
            "lateral_area": 33.6,
            "volume": 42.0,
            "height": 2.8
        }
    ]
    
    return godot_data, mapping_data

def test_ifc_export():
    """Testează exportul IFC cu date simulate"""
    print("=== Test IFC Space Export ===")
    
    # Creează date de test
    godot_data, mapping_data = create_test_data()
    
    # Salvează datele în fișiere temporare
    test_dir = "test_export"
    if not os.path.exists(test_dir):
        os.makedirs(test_dir)
    
    godot_file = os.path.join(test_dir, "test_geometry.json")
    mapping_file = os.path.join(test_dir, "test_mapping.json")
    ifc_file = os.path.join(test_dir, "test_spaces.ifc")
    
    # Salvează JSON-urile
    with open(godot_file, 'w', encoding='utf-8') as f:
        json.dump(godot_data, f, indent=2)
    
    with open(mapping_file, 'w', encoding='utf-8') as f:
        json.dump(mapping_data, f, indent=2)
    
    print(f"Created test files:")
    print(f"  - Geometry: {godot_file}")
    print(f"  - Mapping: {mapping_file}")
    
    # Testează exportul
    try:
        success = export_spaces_to_ifc(
            godot_file, 
            mapping_file, 
            ifc_file, 
            "Test Godot Spaces Project"
        )
        
        if success and os.path.exists(ifc_file):
            file_size = os.path.getsize(ifc_file)
            print(f"✅ IFC export successful!")
            print(f"  - Output file: {ifc_file}")
            print(f"  - File size: {file_size} bytes")
            
            # Verifică conținutul IFC
            with open(ifc_file, 'r', encoding='utf-8') as f:
                content = f.read()
                space_count = content.count('IFCSPACE')
                building_count = content.count('IFCBUILDING')
                print(f"  - IfcSpace entities: {space_count}")
                print(f"  - IfcBuilding entities: {building_count}")
                
                # Verifică proprietățile
                if 'GodotSpaceProperties' in content:
                    print("  - ✅ Custom properties found")
                if 'BaseQuantities' in content:
                    print("  - ✅ Standard quantities found")
                
            return True
        else:
            print("❌ IFC export failed")
            return False
            
    except Exception as e:
        print(f"❌ Test failed with error: {e}")
        import traceback
        traceback.print_exc()
        return False

if __name__ == "__main__":
    # Verifică dependențele
    try:
        import ifcopenshell
        print(f"✅ ifcopenshell version: {ifcopenshell.version}")
    except ImportError:
        print("❌ ifcopenshell not installed. Run: pip install ifcopenshell")
        sys.exit(1)
    
    # Rulează testul
    success = test_ifc_export()
    sys.exit(0 if success else 1)