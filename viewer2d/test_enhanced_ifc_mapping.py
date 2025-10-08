#!/usr/bin/env python3
"""
Test pentru funcțiile noi de îmbogățire a datelor IFC Space cu JSON mapping
"""

import json
import os
from datetime import datetime

def simulate_enhanced_godot_export():
    """Simulează exportul îmbogățit din Godot cu date din JSON mapping"""
    
    # Simulează datele de spațiu din Godot (doar geometria de bază)
    godot_spaces = [
        {
            "mesh_name": "IfcSpace_LivingRoom_1_LAYER_IfcSpace",
            "uuid": "eca6e45f-d09f-4b9f-a43e-4ac8fa21627e",
            "vertices": [[1.125, 12.125, 0.0], [1.125, 16.875, 0.0], [4.875, 16.875, 0.0], [4.875, 12.125, 0.0],
                         [1.125, 12.125, 2.65], [1.125, 16.875, 2.65], [4.875, 16.875, 2.65], [4.875, 12.125, 2.65]],
            "vertex_count": 8
        },
        {
            "mesh_name": "IfcSpace_Kitchen_1_LAYER_IfcSpace", 
            "uuid": "ce455336-687e-4b18-bfad-ba0acd91b346",
            "vertices": [[1.125, 12.125, 0.0], [4.875, 12.125, 0.0], [4.875, 8.375, 0.0], [1.125, 8.375, 0.0],
                         [1.125, 12.125, 2.65], [4.875, 12.125, 2.65], [4.875, 8.375, 2.65], [1.125, 8.375, 2.65]],
            "vertex_count": 8
        }
    ]
    
    # Încarcă datele din JSON de mapare
    mapping_file = "test_enhanced_layers_mapping.json"
    if not os.path.exists(mapping_file):
        print(f"❌ Mapping file not found: {mapping_file}")
        return
    
    with open(mapping_file, 'r', encoding='utf-8') as f:
        mapping_data = json.load(f)
    
    # Filtrează doar spațiile IfcSpace
    space_entries = [entry for entry in mapping_data if entry.get("layer") == "IfcSpace"]
    print(f"📊 Found {len(space_entries)} IfcSpace entries in mapping")
    
    # Îmbogățește datele spațiilor cu valorile din mapping
    enhanced_spaces = []
    
    for godot_space in godot_spaces:
        # Găsește intrarea corespunzătoare în mapping
        mapping_entry = None
        uuid = godot_space["uuid"]
        mesh_name = godot_space["mesh_name"]
        
        # Caută după UUID
        for entry in space_entries:
            if entry.get("uuid") == uuid:
                mapping_entry = entry
                break
        
        # Caută după mesh_name dacă UUID nu funcționează
        if not mapping_entry:
            for entry in space_entries:
                if entry.get("mesh_name") == mesh_name.replace("_LAYER_IfcSpace", ""):
                    mapping_entry = entry
                    break
        
        if mapping_entry:
            # Îmbogățește cu datele din JSON
            enhanced_space = godot_space.copy()
            enhanced_space["area"] = float(mapping_entry.get("area", 0.0))
            enhanced_space["volume"] = float(mapping_entry.get("volume", 0.0))
            enhanced_space["perimeter"] = float(mapping_entry.get("perimeter", 0.0))
            enhanced_space["lateral_area"] = float(mapping_entry.get("lateral_area", 0.0))
            
            # Calculează înălțimea din volum/arie
            if enhanced_space["area"] > 0:
                enhanced_space["height"] = enhanced_space["volume"] / enhanced_space["area"]
            else:
                enhanced_space["height"] = 2.8
            
            enhanced_spaces.append(enhanced_space)
            
            print(f"✅ Enhanced space: {mesh_name}")
            print(f"   Area: {enhanced_space['area']:.3f}m², Perimeter: {enhanced_space['perimeter']:.3f}m")
            print(f"   Lateral Area: {enhanced_space['lateral_area']:.3f}m², Volume: {enhanced_space['volume']:.3f}m³")
            print(f"   Height: {enhanced_space['height']:.3f}m, UUID: {uuid}")
        else:
            print(f"⚠️ No mapping found for: {mesh_name} (UUID: {uuid})")
            # Folosește valorile implicite
            enhanced_space = godot_space.copy()
            enhanced_space.update({
                "area": 0.0, "volume": 0.0, "perimeter": 0.0, 
                "lateral_area": 0.0, "height": 2.8
            })
            enhanced_spaces.append(enhanced_space)
    
    # Creează fișierul de geometrie îmbogățit
    enhanced_data = {
        "spaces": enhanced_spaces,
        "export_timestamp": datetime.now().timestamp()
    }
    
    output_file = "exported_ifc/enhanced_geometry_from_mapping.json"
    os.makedirs("exported_ifc", exist_ok=True)
    
    with open(output_file, 'w', encoding='utf-8') as f:
        json.dump(enhanced_data, f, indent=2, ensure_ascii=False)
    
    print(f"\n📁 Saved enhanced geometry data: {output_file}")
    print(f"📊 Total spaces processed: {len(enhanced_spaces)}")
    
    return output_file

def test_enhanced_ifc_export():
    """Testează exportul IFC cu datele îmbogățite"""
    
    # Generează fișierul îmbogățit
    geometry_file = simulate_enhanced_godot_export()
    if not geometry_file:
        return
    
    # Rulează exporterul IFC cu datele îmbogățite
    import subprocess
    
    cmd = [
        "python", "python/ifc_space_exporter.py",
        geometry_file,
        "test_enhanced_layers_mapping.json", 
        "exported_ifc/enhanced_with_mapping.ifc",
        "Enhanced IFC with JSON Mapping Data"
    ]
    
    print(f"\n🚀 Running IFC export: {' '.join(cmd)}")
    result = subprocess.run(cmd, capture_output=True, text=True)
    
    print("STDOUT:", result.stdout)
    if result.stderr:
        print("STDERR:", result.stderr)
    print("Exit code:", result.returncode)

if __name__ == "__main__":
    test_enhanced_ifc_export()