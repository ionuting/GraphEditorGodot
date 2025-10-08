#!/usr/bin/env python3
"""
Script de inițializare pentru sistemul de reload îmbunătățit
Configurează toate dependințele și testează sistemul
"""

import os
import sys
import subprocess
import time
from pathlib import Path

def install_dependencies():
    """Instalează dependințele Python necesare"""
    print("📦 Instalare dependințe Python...")
    
    dependencies = [
        "watchdog",
        "ezdxf", 
        "trimesh",
        "shapely",
        "numpy"
    ]
    
    for dep in dependencies:
        try:
            __import__(dep)
            print(f"   ✓ {dep} - deja instalat")
        except ImportError:
            print(f"   📥 Instalez {dep}...")
            result = subprocess.run([sys.executable, "-m", "pip", "install", dep], 
                                  capture_output=True, text=True)
            if result.returncode == 0:
                print(f"   ✓ {dep} - instalat cu succes")
            else:
                print(f"   ❌ {dep} - eroare la instalare: {result.stderr}")
                return False
    
    return True

def setup_project_structure():
    """Creează structura de foldere pentru proiect"""
    print("\n📁 Configurez structura proiectului...")
    
    project_folder = Path(r"C:\Users\ionut.ciuntuc\Documents\viewer2d")
    
    folders_to_create = [
        "python",
        "dxf_input", 
        "glb_output",
        "test_dxf",
        ".godot/imported"  # Pentru cache Godot
    ]
    
    for folder in folders_to_create:
        folder_path = project_folder / folder
        folder_path.mkdir(parents=True, exist_ok=True)
        print(f"   ✓ {folder}")
    
    return project_folder

def create_test_files(project_folder):
    """Creează fișiere de test pentru verificarea sistemului"""
    print("\n🧪 Creez fișiere de test...")
    
    # Creează un DXF de test simplu
    test_dxf = project_folder / "dxf_input" / "test_reload.dxf"
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
TestLayer
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
2.8
0
ENDSEC
0
EOF
"""
    
    with open(test_dxf, 'w') as f:
        f.write(dxf_content)
    print(f"   ✓ Test DXF: {test_dxf.name}")
    
    # Creează un fișier de configurare pentru layer materials
    materials_file = project_folder / "layer_materials.csv"
    if not materials_file.exists():
        materials_content = """layer,color,alpha
TestLayer,"[0.0, 1.0, 0.0]",1.0
IfcWall,"[0.8, 0.8, 0.8]",1.0
IfcSlab,"[0.6, 0.6, 0.6]",1.0
IfcColumn,"[0.4, 0.4, 0.4]",1.0
IfcWindow,"[0.7, 0.9, 1.0]",0.8
default,"[0.5, 1.0, 0.0]",1.0
"""
        with open(materials_file, 'w') as f:
            f.write(materials_content)
        print(f"   ✓ Layer materials: {materials_file.name}")

def test_conversion_system(project_folder):
    """Testează sistemul de conversie DXF → GLB"""
    print("\n🔄 Testez sistemul de conversie...")
    
    # Verifică dacă scriptul de conversie există
    conversion_script = project_folder / "python" / "dxf_to_glb_trimesh.py"
    if not conversion_script.exists():
        print(f"   ❌ Scriptul de conversie nu există: {conversion_script}")
        return False
    
    # Testează conversia
    test_dxf = project_folder / "dxf_input" / "test_reload.dxf"
    test_glb = project_folder / "glb_output" / "test_reload.glb"
    
    print(f"   🔄 Conversie: {test_dxf.name} → {test_glb.name}")
    
    try:
        result = subprocess.run([
            sys.executable,
            str(conversion_script),
            str(test_dxf),
            str(test_glb)
        ], capture_output=True, text=True, timeout=30)
        
        if result.returncode == 0:
            # Așteaptă un moment ca fișierul să fie complet scris
            time.sleep(0.5)
            if test_glb.exists():
                file_size = test_glb.stat().st_size
                print(f"   ✅ Conversie reușită! GLB: {file_size} bytes")
                return True
            else:
                print(f"   ❌ GLB nu a fost generat")
                return False
        else:
            print(f"   ❌ Conversie eșuată:")
            print(f"      Exit code: {result.returncode}")
            print(f"      Stdout: {result.stdout}")
            print(f"      Stderr: {result.stderr}")
            return False
    
    except subprocess.TimeoutExpired:
        print(f"   ❌ Conversie timeout (>30s)")
        return False
    except Exception as e:
        print(f"   ❌ Eroare la conversie: {e}")
        return False

def test_watchdog_system(project_folder):
    """Testează sistemul watchdog"""
    print("\n👁️  Testez sistemul watchdog...")
    
    watchdog_script = project_folder / "python" / "dxf_watchdog.py"
    if not watchdog_script.exists():
        print(f"   ❌ Scriptul watchdog nu există: {watchdog_script}")
        return False
    
    # Verifică doar că scriptul se poate importa corect
    try:
        # Testează importurile
        import watchdog
        print(f"   ✓ Watchdog library disponibilă")
        
        # Nu pornim watchdog-ul în test, doar verificăm că se poate citi
        with open(watchdog_script, 'r') as f:
            content = f.read()
            if "class DXFHandler" in content and "def main()" in content:
                print(f"   ✓ Watchdog script valid")
                return True
            else:
                print(f"   ❌ Watchdog script invalid")
                return False
    
    except ImportError as e:
        print(f"   ❌ Watchdog library lipsește: {e}")
        return False
    except Exception as e:
        print(f"   ❌ Eroare la testarea watchdog: {e}")
        return False

def print_usage_instructions():
    """Afișează instrucțiunile de utilizare"""
    print(f"\n" + "="*60)
    print(f"🎉 SISTEM DE RELOAD ÎMBUNĂTĂȚIT GATA!")
    print(f"="*60)
    print(f"""
📋 INSTRUCȚIUNI DE UTILIZARE:

1. 🎮 În Godot:
   • Apasă butonul 'Load DXF' pentru a selecta folderul cu DXF-uri
   • Apasă butonul 'Reload' pentru a reîncărca toate GLB-urile
   • Sistemul va forța regenerarea fișierelor .import

2. 🔄 Pentru monitorizare automată:
   • Rulează: python python/dxf_watchdog.py
   • Modifică orice fișier DXF din folderul monitorizat
   • Godot va detecta automat schimbările

3. 🐛 Pentru debugging:
   • Rulează: python debug_reload_monitor.py
   • Monitorizează în timp real fișierele GLB și .import

4. 🧪 Pentru teste:
   • Rulează: python test_reload_system.py
   • Verifică că sistemul funcționează corect

📁 FOLDERE IMPORTANTE:
   • dxf_input/  - Pune aici fișierele DXF
   • glb_output/ - Aici se generează GLB-urile
   • .godot/imported/ - Cache Godot (se curăță automat)

⚙️ FUNCȚII NOI:
   • Ștergere completă cache .import
   • Regenerare forțată GLB
   • Modificare timestamp pentru reimport
   • Curățare .godot/imported/
   • Monitorizare file system

🔧 DEBUGGING:
   • Verifică console-ul Godot pentru mesaje [DEBUG]
   • Folosește debug_reload_monitor.py pentru monitorizare
   • Fișierele .import trebuie să lipsească după reload
    """)

def main():
    print("🚀 Inițializez sistemul de reload îmbunătățit pentru Godot DXF viewer...")
    print("="*60)
    
    # Pasul 1: Instalează dependințele
    if not install_dependencies():
        print("❌ Eroare la instalarea dependințelor!")
        return
    
    # Pasul 2: Configurează structura proiectului
    project_folder = setup_project_structure()
    
    # Pasul 3: Creează fișiere de test
    create_test_files(project_folder)
    
    # Pasul 4: Testează conversia
    conversion_ok = test_conversion_system(project_folder)
    
    # Pasul 5: Testează watchdog
    watchdog_ok = test_watchdog_system(project_folder)
    
    # Pasul 6: Raport final
    print(f"\n📊 RAPORT FINAL:")
    print(f"   Dependințe: ✅")
    print(f"   Structură proiect: ✅")
    print(f"   Fișiere test: ✅")
    print(f"   Conversie DXF→GLB: {'✅' if conversion_ok else '❌'}")
    print(f"   Sistem watchdog: {'✅' if watchdog_ok else '❌'}")
    
    if conversion_ok and watchdog_ok:
        print_usage_instructions()
    else:
        print(f"\n❌ Unele componente au probleme. Verifică erorile de mai sus.")

if __name__ == "__main__":
    main()