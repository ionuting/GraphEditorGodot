#!/usr/bin/env python3
"""
Script rapid pentru testarea încărcării GLB în Godot
Verifică dacă fișierele GLB sunt corupte sau au probleme de format
"""

import os
import sys
from pathlib import Path

def check_glb_files(folder_path):
    """Verifică toate fișierele GLB dintr-un folder"""
    folder = Path(folder_path)
    
    if not folder.exists():
        print(f"❌ Folderul nu există: {folder_path}")
        return
    
    glb_files = list(folder.glob("*.glb"))
    
    if not glb_files:
        print(f"❌ Nu s-au găsit fișiere GLB în: {folder_path}")
        return
    
    print(f"📁 Verificare {len(glb_files)} fișiere GLB în: {folder_path}")
    print("="*60)
    
    for glb_file in glb_files:
        print(f"\n🔍 {glb_file.name}:")
        
        # Verifică dimensiunea
        size = glb_file.stat().st_size
        print(f"   📏 Dimensiune: {size:,} bytes")
        
        if size < 100:
            print(f"   ❌ Fișier prea mic (posibil corupt)")
            continue
        
        # Verifică magic number
        try:
            with open(glb_file, 'rb') as f:
                magic = f.read(4)
                if magic == b'glTF':
                    print(f"   ✅ Magic number GLB valid")
                    
                    # Citește versiunea
                    version = int.from_bytes(f.read(4), byteorder='little')
                    print(f"   📊 Versiune GLB: {version}")
                    
                    # Citește lungimea totală
                    total_length = int.from_bytes(f.read(4), byteorder='little')
                    print(f"   📐 Lungime declarată: {total_length:,} bytes")
                    
                    if total_length != size:
                        print(f"   ⚠️  Nepotrivire dimensiune: declarată {total_length}, reală {size}")
                    else:
                        print(f"   ✅ Dimensiune GLB corectă")
                        
                else:
                    print(f"   ❌ Magic number invalid: {magic}")
                    
        except Exception as e:
            print(f"   ❌ Eroare la citire: {e}")
        
        # Verifică fișierul .import
        import_file = Path(str(glb_file) + ".import")
        if import_file.exists():
            print(f"   📋 Fișier .import: EXISTS")
            
            try:
                with open(import_file, 'r') as f:
                    content = f.read()
                    if 'PackedScene' in content:
                        print(f"   ✅ Configurat pentru PackedScene")
                    else:
                        print(f"   ⚠️  NU e configurat pentru PackedScene")
                        
                    if 'scene' in content.lower():
                        print(f"   ✅ Scene importer detectat")
                    else:
                        print(f"   ❌ Scene importer NU detectat")
                        
            except Exception as e:
                print(f"   ❌ Eroare la citirea .import: {e}")
        else:
            print(f"   ⚠️  Fișier .import: MISSING (va fi generat de Godot)")

def main():
    if len(sys.argv) > 1:
        folder_path = sys.argv[1]
    else:
        folder_path = r"C:\Users\ionut.ciuntuc\Documents\viewer2d\python\dxf"
    
    check_glb_files(folder_path)
    
    print(f"\n" + "="*60)
    print(f"🎯 RECOMANDĂRI:")
    print(f"   • Fișierele cu magic number invalid sunt corupte")
    print(f"   • Fișierele fără .import vor fi procesate de Godot la prima încărcare")
    print(f"   • Nepotrivirile de dimensiune indică probleme de generare")
    print(f"   • Toate GLB-urile trebuie configurate pentru PackedScene în .import")

if __name__ == "__main__":
    main()