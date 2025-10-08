#!/usr/bin/env python3
"""
Script de debug pentru monitorizarea fișierelor GLB și .import
Ajută la diagnosticarea problemelor de reload în Godot
"""

import os
import time
from pathlib import Path
from datetime import datetime

def monitor_reload_files(project_folder, duration_seconds=60):
    """Monitorizează fișierele GLB și .import pentru o perioadă specificată"""
    project_path = Path(project_folder)
    
    print(f"=== Monitor pentru fișierele de reload ===")
    print(f"Folder: {project_path}")
    print(f"Durată: {duration_seconds} secunde")
    print(f"Timp start: {datetime.now().strftime('%H:%M:%S')}")
    print(f"Apasă Ctrl+C pentru a opri mai devreme\n")
    
    # Găsește toate fișierele GLB din proiect
    glb_files = list(project_path.rglob("*.glb"))
    
    if not glb_files:
        print("❌ Nu s-au găsit fișiere GLB în proiect!")
        return
    
    print(f"📁 Găsite {len(glb_files)} fișiere GLB:")
    for glb_file in glb_files:
        print(f"   • {glb_file.relative_to(project_path)}")
    print()
    
    # Monitorizează fișierele
    start_time = time.time()
    last_status = {}
    
    try:
        while time.time() - start_time < duration_seconds:
            current_time = datetime.now().strftime('%H:%M:%S')
            status_changed = False
            
            for glb_file in glb_files:
                import_file = Path(str(glb_file) + ".import")
                
                # Verifică statusul curent
                glb_exists = glb_file.exists()
                import_exists = import_file.exists()
                
                # Obține informații despre fișiere
                glb_size = glb_file.stat().st_size if glb_exists else 0
                glb_mtime = glb_file.stat().st_mtime if glb_exists else 0
                import_mtime = import_file.stat().st_mtime if import_exists else 0
                
                current_status = {
                    'glb_exists': glb_exists,
                    'import_exists': import_exists,
                    'glb_size': glb_size,
                    'glb_mtime': glb_mtime,
                    'import_mtime': import_mtime
                }
                
                file_key = str(glb_file.relative_to(project_path))
                
                # Verifică dacă s-a schimbat ceva
                if file_key not in last_status or last_status[file_key] != current_status:
                    if not status_changed:
                        print(f"[{current_time}] Schimbări detectate:")
                        status_changed = True
                    
                    print(f"  📄 {file_key}:")
                    print(f"      GLB: {'✓' if glb_exists else '✗'} ({glb_size} bytes)")
                    print(f"      Import: {'✓' if import_exists else '✗'}")
                    
                    if glb_exists:
                        mtime_str = datetime.fromtimestamp(glb_mtime).strftime('%H:%M:%S')
                        print(f"      GLB modificat: {mtime_str}")
                    
                    if import_exists:
                        import_mtime_str = datetime.fromtimestamp(import_mtime).strftime('%H:%M:%S')
                        print(f"      Import modificat: {import_mtime_str}")
                    
                    # Analizează starea
                    if glb_exists and not import_exists:
                        print(f"      🟢 STATUS: GLB fără .import (bun pentru reload)")
                    elif glb_exists and import_exists:
                        if glb_mtime > import_mtime:
                            print(f"      🟡 STATUS: GLB mai nou ca .import (posibil reload în curs)")
                        else:
                            print(f"      🔵 STATUS: GLB și .import sincronizate")
                    elif not glb_exists and import_exists:
                        print(f"      🔴 STATUS: .import fără GLB (problemă!)")
                    else:
                        print(f"      ⚫ STATUS: Nici GLB, nici .import")
                    
                    print()
                
                last_status[file_key] = current_status
            
            time.sleep(0.5)  # Verifică la fiecare 0.5 secunde
            
    except KeyboardInterrupt:
        print(f"\n⏹️  Monitorizare oprită de utilizator")
    
    print(f"\n=== Monitor terminat la {datetime.now().strftime('%H:%M:%S')} ===")

def check_godot_cache(project_folder):
    """Verifică cache-ul Godot pentru fișierele GLB"""
    project_path = Path(project_folder)
    godot_folder = project_path / ".godot"
    imported_folder = godot_folder / "imported"
    
    print(f"=== Verificare cache Godot ===")
    print(f"Folder .godot: {'✓' if godot_folder.exists() else '✗'}")
    print(f"Folder imported: {'✓' if imported_folder.exists() else '✗'}")
    
    if not imported_folder.exists():
        print("❌ Nu există folderul .godot/imported/")
        return
    
    # Găsește fișierele GLB din cache
    cache_files = list(imported_folder.glob("*.scn"))
    glb_cache_files = [f for f in cache_files if "glb" in f.name.lower()]
    
    print(f"\n📁 Cache-uri GLB găsite: {len(glb_cache_files)}")
    for cache_file in glb_cache_files:
        size = cache_file.stat().st_size
        mtime = datetime.fromtimestamp(cache_file.stat().st_mtime).strftime('%Y-%m-%d %H:%M:%S')
        print(f"   • {cache_file.name} ({size} bytes, modificat: {mtime})")

def main():
    project_folder = r"C:\Users\ionut.ciuntuc\Documents\viewer2d"
    
    print("Opțiuni:")
    print("1. Monitorizează fișierele pentru 30 secunde")
    print("2. Monitorizează fișierele pentru 60 secunde")
    print("3. Verifică cache-ul Godot")
    print("4. Monitorizează continuu (Ctrl+C pentru a opri)")
    
    choice = input("\nAlegeți opțiunea (1-4): ").strip()
    
    if choice == "1":
        monitor_reload_files(project_folder, 30)
    elif choice == "2":
        monitor_reload_files(project_folder, 60)
    elif choice == "3":
        check_godot_cache(project_folder)
    elif choice == "4":
        monitor_reload_files(project_folder, 999999)  # Un timp foarte lung
    else:
        print("Opțiune invalidă!")

if __name__ == "__main__":
    main()