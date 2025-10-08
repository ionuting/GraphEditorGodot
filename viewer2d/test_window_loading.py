#!/usr/bin/env python3
"""
Script pentru testarea funcționalității de încărcare a ferestrelor GLTF.
Simulează workflow-ul din Godot.
"""
import json
import os

def test_window_loading():
    # Citește mapping-ul generat
    mapping_path = "python/test_windows_with_gltf_mapping.json"
    
    if not os.path.exists(mapping_path):
        print(f"ERROR: Mapping file not found: {mapping_path}")
        return
    
    with open(mapping_path, 'r', encoding='utf-8') as f:
        mapping_data = json.load(f)
    
    print("=== WINDOW LOADING TEST ===")
    print(f"Found {len(mapping_data)} entries in mapping")
    
    window_count = 0
    geometry_count = 0
    
    for entry in mapping_data:
        entry_type = entry.get("type", "unknown")
        
        if entry_type == "window_block":
            window_count += 1
            window_name = entry.get("window_name", "Unknown")
            gltf_file = entry.get("gltf_file", "")
            position = entry.get("position", {})
            rotation = entry.get("rotation", {})
            
            print(f"\n[WINDOW {window_count}] {window_name}")
            print(f"  GLTF File: {gltf_file}")
            print(f"  Position: ({position.get('x', 0):.2f}, {position.get('y', 0):.2f}, {position.get('z', 0):.2f})")
            print(f"  Rotation: {rotation.get('z', 0):.1f}°")
            
            # Verifică dacă fișierul GLTF există
            if os.path.exists(gltf_file):
                print(f"  Status: ✓ GLTF file found")
            else:
                print(f"  Status: ✗ GLTF file NOT found")
                
        else:
            geometry_count += 1
            mesh_name = entry.get("mesh_name", "Unknown")
            layer = entry.get("layer", "Unknown")
            role = entry.get("role", 0)
            
            role_str = "SOLID" if role == 1 else "VOID" if role == -1 else "UNKNOWN"
            print(f"\n[GEOMETRY {geometry_count}] {mesh_name}")
            print(f"  Layer: {layer}")
            print(f"  Role: {role_str}")
    
    print(f"\n=== SUMMARY ===")
    print(f"Total windows: {window_count}")
    print(f"Total geometry: {geometry_count}")
    print(f"Total entries: {len(mapping_data)}")
    
    # Verifică biblioteca GLTF
    library_path = "library/gltf library/Windows"
    if os.path.exists(library_path):
        gltf_files = [f for f in os.listdir(library_path) if f.lower().endswith(('.gltf', '.glb'))]
        print(f"\nGLTF Library contains {len(gltf_files)} files:")
        for gltf_file in gltf_files:
            print(f"  - {gltf_file}")
    else:
        print(f"\nWARNING: GLTF library not found at: {library_path}")
    
    print("\n=== GODOT INTEGRATION INSTRUCTIONS ===")
    print("1. Copy the GLTF library folder to your Godot project")
    print("2. Import the GLB file in Godot using the Load DXF button")
    print("3. The windows should automatically load and position based on mapping")
    print("4. Check the Objects tree to see both geometry and windows")

if __name__ == "__main__":
    test_window_loading()