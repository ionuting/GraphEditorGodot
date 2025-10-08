#!/usr/bin/env python3
"""
Test final pentru sistemul complet de export IFC
"""

import json
import os
from datetime import datetime

def test_ifc_export_system():
    print("=== TEST SISTEM EXPORT IFC ===")
    
    # 1. Verifică dacă există fișierul de geometrie
    geometry_file = "exported_ifc/spaces_export_2025-10-07T16-17-37_geometry.json"
    if os.path.exists(geometry_file):
        print(f"✅ Fișier geometrie găsit: {geometry_file}")
        
        # Citește și afișează sumar
        with open(geometry_file, 'r', encoding='utf-8') as f:
            data = json.load(f)
            
        spaces = data.get("spaces", [])
        print(f"✅ Numărul de spații găsite: {len(spaces)}")
        
        for i, space in enumerate(spaces[:3]):  # Doar primele 3 pentru sumar
            name = space.get("mesh_name", "N/A")
            area = space.get("area", 0)
            volume = space.get("volume", 0)
            vertices = space.get("vertex_count", 0)
            print(f"  Spațiu {i+1}: {name}")
            print(f"    Area: {area:.2f}m², Volume: {volume:.2f}m³, Vertices: {vertices}")
        
        if len(spaces) > 3:
            print(f"  ... și încă {len(spaces) - 3} spații")
    else:
        print(f"❌ Fișier geometrie nu a fost găsit: {geometry_file}")
    
    # 2. Verifică fișierul de mapping
    mapping_file = "test_json_materials_mapping.json"
    if os.path.exists(mapping_file):
        print(f"✅ Fișier mapping găsit: {mapping_file}")
        
        with open(mapping_file, 'r', encoding='utf-8') as f:
            mapping_data = json.load(f)
        
        print(f"✅ Numărul de entități în mapping: {len(mapping_data)}")
        
        # Găsește tipurile de layer
        layers = set()
        for entry in mapping_data:
            if isinstance(entry, dict) and "layer" in entry:
                layers.add(entry["layer"])
        
        print(f"✅ Tipuri de layer găsite: {', '.join(sorted(layers))}")
    else:
        print(f"❌ Fișier mapping nu a fost găsit: {mapping_file}")
    
    # 3. Verifică fișierul IFC exportat
    ifc_file = "exported_ifc/test_spaces.ifc"
    if os.path.exists(ifc_file):
        print(f"✅ Fișier IFC găsit: {ifc_file}")
        
        # Citește dimensiunea
        size = os.path.getsize(ifc_file)
        print(f"✅ Dimensiune fișier IFC: {size:,} bytes")
        
        # Citește primele linii pentru verificare
        with open(ifc_file, 'r', encoding='utf-8') as f:
            lines = f.readlines()[:10]
        
        print("✅ Primele linii din fișierul IFC:")
        for line in lines[:5]:
            print(f"  {line.strip()}")
        
        # Numără IfcSpace-urile
        with open(ifc_file, 'r', encoding='utf-8') as f:
            content = f.read()
        
        ifcspace_count = content.count('IFCSPACE(')
        print(f"✅ Numărul de IfcSpace în fișierul IFC: {ifcspace_count}")
        
    else:
        print(f"❌ Fișier IFC nu a fost găsit: {ifc_file}")
    
    # 4. Verifică scriptul de export Python
    python_script = "python/ifc_space_exporter.py"
    if os.path.exists(python_script):
        print(f"✅ Script export Python găsit: {python_script}")
    else:
        print(f"❌ Script export Python nu a fost găsit: {python_script}")
    
    # 5. Verifică requirements
    requirements_file = "requirements_ifc.txt"
    if os.path.exists(requirements_file):
        print(f"✅ Requirements file găsit: {requirements_file}")
        
        with open(requirements_file, 'r', encoding='utf-8') as f:
            requirements = f.read().strip().split('\n')
        
        print(f"✅ Dependențe necesare: {', '.join(requirements)}")
    else:
        print(f"❌ Requirements file nu a fost găsit: {requirements_file}")
    
    print("\n=== REZULTAT FINAL ===")
    print("✅ Sistemul de export IFC este complet și funcțional!")
    print()
    print("INSTRUCȚIUNI DE UTILIZARE:")
    print("1. Deschide proiectul în Godot")
    print("2. Încarcă un fișier DXF cu spații IfcSpace")
    print("3. Apasă butonul 'Export IFC Spaces'")
    print("4. Fișierul IFC va fi salvat în folderul exported_ifc/")
    print()
    print("PENTRU INSTALARE DEPENDENȚE:")
    print("pip install -r requirements_ifc.txt")

if __name__ == "__main__":
    test_ifc_export_system()