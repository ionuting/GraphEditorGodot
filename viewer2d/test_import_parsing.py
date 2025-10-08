#!/usr/bin/env python3
"""
Test pentru verificarea parsing-ului fișierului .import
"""

def test_import_parsing():
    import_file = r"C:\Users\ionut.ciuntuc\Documents\viewer2d\python\dxf\1SecondFloor.glb.import"
    
    try:
        with open(import_file, 'r') as f:
            content = f.read()
        
        print("📋 Conținut fișier .import:")
        print("="*50)
        print(content)
        print("="*50)
        
        # Simulează parsing-ul Godot
        lines = content.split('\n')
        scn_path = ""
        
        for line in lines:
            if line.startswith('path='):
                print(f"🔍 Linia cu path găsită: {line}")
                
                # Extrage calea dintre ghilimele
                start_quote = line.find('"')
                end_quote = line.find('"', start_quote + 1)
                
                if start_quote >= 0 and end_quote > start_quote:
                    scn_path = line[start_quote + 1:end_quote]
                    print(f"✅ Path extras: {scn_path}")
                    break
        
        if scn_path:
            # Convertește la calea fizică pentru verificare
            if scn_path.startswith("res://"):
                physical_path = scn_path.replace("res://", r"C:\Users\ionut.ciuntuc\Documents\viewer2d\\")
                physical_path = physical_path.replace("/", "\\")
                
                print(f"📁 Calea fizică: {physical_path}")
                
                import os
                if os.path.exists(physical_path):
                    size = os.path.getsize(physical_path)
                    print(f"✅ Fișierul .scn există ({size:,} bytes)")
                else:
                    print(f"❌ Fișierul .scn NU există")
        else:
            print("❌ Nu s-a putut extrage path-ul")
            
    except Exception as e:
        print(f"❌ Eroare: {e}")

if __name__ == "__main__":
    test_import_parsing()