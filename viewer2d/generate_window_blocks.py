#!/usr/bin/env python3
"""
Utility pentru crearea automată a definițiilor de blocuri DXF bazate pe fișierele GLTF din bibliotecă.
"""
import os
import ezdxf
import json

def scan_gltf_library(library_path):
    """Scanează biblioteca GLTF și returnează lista fișierelor găsite."""
    windows_path = os.path.join(library_path, "Windows")
    gltf_files = []
    
    if os.path.exists(windows_path):
        for file in os.listdir(windows_path):
            if file.lower().endswith(('.gltf', '.glb')):
                block_name = os.path.splitext(file)[0]
                gltf_files.append({
                    "block_name": block_name,
                    "file_path": os.path.join("Windows", file),
                    "full_path": os.path.join(windows_path, file)
                })
                print(f"Found GLTF: {block_name} -> {file}")
    
    return gltf_files

def create_block_definitions_dxf(gltf_files, output_path):
    """Creează un DXF cu definițiile de blocuri pentru toate fișierele GLTF."""
    doc = ezdxf.new('R2010')
    msp = doc.modelspace()
    
    # Creează definițiile de blocuri
    for gltf_info in gltf_files:
        block_name = gltf_info["block_name"]
        
        # Creează blocul
        try:
            block_def = doc.blocks.new(name=block_name)
            
            # Adaugă o geometrie simplă reprezentativă (cadru fereastră)
            # Aceasta va fi înlocuită cu GLTF în Godot
            width = 1.2  # Presupunem 1.2m lățime standard
            height = 1.2  # Presupunem 1.2m înălțime standard
            
            # Cadrul exterior
            block_def.add_line(start=(0, 0), end=(width, 0))
            block_def.add_line(start=(width, 0), end=(width, height))
            block_def.add_line(start=(width, height), end=(0, height))
            block_def.add_line(start=(0, height), end=(0, 0))
            
            # Cadrul interior (pentru reprezentare vizuală)
            offset = 0.1
            block_def.add_line(start=(offset, offset), end=(width-offset, offset))
            block_def.add_line(start=(width-offset, offset), end=(width-offset, height-offset))
            block_def.add_line(start=(width-offset, height-offset), end=(offset, height-offset))
            block_def.add_line(start=(offset, height-offset), end=(offset, offset))
            
            # Linia diagonală pentru identificare
            block_def.add_line(start=(0, 0), end=(width, height))
            
            print(f"Created block definition: {block_name}")
            
        except Exception as ex:
            print(f"Error creating block {block_name}: {ex}")
    
    # Adaugă câteva exemple de inserare pentru test
    if gltf_files:
        example_block = gltf_files[0]["block_name"]
        
        # Exemplu de fereastră cu diferite orientări
        msp.add_blockref(example_block, (0, 0), dxfattribs={"layer": "IfcWindow"})
        msp.add_blockref(example_block, (3, 0), dxfattribs={"layer": "IfcWindow", "rotation": 90})
        msp.add_blockref(example_block, (3, 3), dxfattribs={"layer": "IfcWindow", "rotation": 180})
        msp.add_blockref(example_block, (0, 3), dxfattribs={"layer": "IfcWindow", "rotation": 270})
    
    # Salvează documentul
    doc.saveas(output_path)
    print(f"Saved block definitions to: {output_path}")

def create_library_info_json(gltf_files, output_path):
    """Creează un fișier JSON cu informații despre biblioteca GLTF."""
    library_info = {
        "version": "1.0",
        "description": "GLTF Window Library for DXF-Godot Pipeline",
        "windows": []
    }
    
    for gltf_info in gltf_files:
        window_info = {
            "block_name": gltf_info["block_name"],
            "gltf_file": gltf_info["file_path"],
            "category": "Windows",
            "default_size": {
                "width": 1.2,
                "height": 1.2,
                "depth": 0.15
            },
            "description": f"Window from {gltf_info['file_path']}"
        }
        library_info["windows"].append(window_info)
    
    with open(output_path, 'w', encoding='utf-8') as f:
        json.dump(library_info, f, indent=2, ensure_ascii=False)
    
    print(f"Saved library info to: {output_path}")

def main():
    # Calea către biblioteca GLTF
    library_path = "library/gltf library"
    
    if not os.path.exists(library_path):
        print(f"Library path not found: {library_path}")
        return
    
    # Scanează biblioteca
    gltf_files = scan_gltf_library(library_path)
    
    if not gltf_files:
        print("No GLTF files found in library")
        return
    
    print(f"Found {len(gltf_files)} GLTF files")
    
    # Creează DXF cu definițiile de blocuri
    create_block_definitions_dxf(gltf_files, "window_library_blocks.dxf")
    
    # Creează fișierul JSON cu informații despre bibliotecă
    create_library_info_json(gltf_files, "gltf_library_info.json")
    
    print("\nGenerated files:")
    print("- window_library_blocks.dxf: Contains block definitions for all GLTF files")
    print("- gltf_library_info.json: Contains metadata about the GLTF library")
    print("\nTo use:")
    print("1. Import block definitions from window_library_blocks.dxf into your CAD software")
    print("2. Insert blocks on IfcWindow layer with proper XDATA (z, height, Name)")
    print("3. Set rotation angle in block properties for orientation")

if __name__ == "__main__":
    main()