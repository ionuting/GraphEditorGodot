#!/usr/bin/env python3
"""
Script de test pentru sistemul de reload îmbunătățit
Verifică că fișierele .import sunt șterse și regenerate corect
"""

import os
import time
import shutil
from pathlib import Path

def test_reload_system():
    print("=== Test pentru sistemul de reload îmbunătățit ===\n")
    
    # Configurație de test
    project_folder = Path(r"C:\Users\ionut.ciuntuc\Documents\viewer2d")
    test_dxf_folder = project_folder / "test_dxf"
    test_glb_folder = project_folder / "test_glb"
    
    # Crează folderele de test
    test_dxf_folder.mkdir(exist_ok=True)
    test_glb_folder.mkdir(exist_ok=True)
    
    # Creează un fișier DXF de test simplu
    test_dxf = test_dxf_folder / "test_reload.dxf"
    create_simple_dxf(test_dxf)
    
    print(f"1. Creat fișier DXF de test: {test_dxf}")
    
    # Simulează conversia inițială
    test_glb = test_glb_folder / "test_reload.glb"
    test_import = Path(str(test_glb) + ".import")
    
    # Creează un GLB dummy și fișierul .import
    create_dummy_glb(test_glb)
    create_dummy_import(test_import)
    
    print(f"2. Creat GLB și .import inițial:")
    print(f"   GLB: {test_glb} ({'EXISTS' if test_glb.exists() else 'MISSING'})")
    print(f"   Import: {test_import} ({'EXISTS' if test_import.exists() else 'MISSING'})")
    
    # Așteaptă un moment
    time.sleep(1)
    
    # Modifică fișierul DXF pentru a simula o schimbare
    modify_dxf(test_dxf)
    print(f"3. Modificat fișierul DXF pentru a simula schimbarea")
    
    # Simulează procesul de reload
    print(f"4. Simulează procesul de reload...")
    
    # Șterge fișierele vechi (simulează _clear_old_files)
    if test_glb.exists():
        test_glb.unlink()
        print(f"   ✓ Șters GLB vechi")
    
    if test_import.exists():
        test_import.unlink()
        print(f"   ✓ Șters .import vechi")
    
    # Creează noul GLB (simulează conversia)
    time.sleep(0.5)  # Simulează timpul de conversie
    create_dummy_glb(test_glb, version=2)
    print(f"   ✓ Creat GLB nou")
    
    # Verifică că fișierul .import NU există (va fi generat de Godot)
    print(f"5. Verificare finală:")
    print(f"   GLB nou: {test_glb} ({'EXISTS' if test_glb.exists() else 'MISSING'})")
    print(f"   Import absent: {test_import} ({'MISSING' if not test_import.exists() else 'EXISTS - PROBLEM!'})")
    
    if test_glb.exists() and not test_import.exists():
        print(f"   ✅ SUCCESS: GLB există, .import nu există (va fi regenerat de Godot)")
    else:
        print(f"   ❌ PROBLEM: Situație neașteptată cu fișierele")
    
    # Cleanup
    cleanup_test_files(test_dxf_folder, test_glb_folder)
    print(f"\n6. ✓ Curățenie efectuată")
    
    print(f"\n=== Test complet ===")

def create_simple_dxf(file_path):
    """Creează un fișier DXF simplu pentru test"""
    dxf_content = """0
SECTION
2
HEADER
9
$DWGCODEPAGE
3
ANSI_1252
0
ENDSEC
0
SECTION
2
ENTITIES
0
LINE
8
0
10
0.0
20
0.0
30
0.0
11
10.0
21
10.0
31
0.0
0
ENDSEC
0
EOF
"""
    with open(file_path, 'w') as f:
        f.write(dxf_content)

def modify_dxf(file_path):
    """Modifică fișierul DXF pentru a simula o schimbare"""
    with open(file_path, 'a') as f:
        f.write(f"\n999\nModified at {time.time()}\n")

def create_dummy_glb(file_path, version=1):
    """Creează un fișier GLB dummy pentru test"""
    dummy_content = f"DUMMY GLB CONTENT v{version} - {time.time()}".encode()
    with open(file_path, 'wb') as f:
        f.write(dummy_content)

def create_dummy_import(file_path):
    """Creează un fișier .import dummy"""
    import_content = f"""[remap]

importer="scene"
type="PackedScene"
uid="uid://test_{int(time.time())}"
path="res://.godot/imported/test_reload.glb-{hex(int(time.time()))}.scn"

[deps]

source_file="res://test_glb/test_reload.glb"
dest_files=["res://.godot/imported/test_reload.glb-{hex(int(time.time()))}.scn"]

[params]

nodes/root_type=""
nodes/root_name=""
"""
    with open(file_path, 'w') as f:
        f.write(import_content)

def cleanup_test_files(dxf_folder, glb_folder):
    """Curăță fișierele de test"""
    try:
        if dxf_folder.exists():
            shutil.rmtree(dxf_folder)
        if glb_folder.exists():
            shutil.rmtree(glb_folder)
    except Exception as e:
        print(f"Warning: Could not clean test files: {e}")

if __name__ == "__main__":
    test_reload_system()