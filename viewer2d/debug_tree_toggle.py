#!/usr/bin/env python3
"""
Script pentru testarea problemei cu toggle-ul de vizualizare în CAD Viewer
Verifică posibile cauze ale problemei
"""

import json
import os
import re

def check_tree_configuration():
    """Verifică configurația tree-ului în fișierul de scenă"""
    
    print("🔍 === ANALIZĂ PROBLEMĂ TOGGLE VIZUALIZARE ===\n")
    
    scene_file = "dxf_to_3D.tscn"
    if os.path.exists(scene_file):
        with open(scene_file, 'r') as f:
            scene_content = f.read()
        
        print("📁 VERIFICARE CONFIGURAȚIE SCENĂ:")
        
        # Verifică dacă tree-ul Objects există și este corect configurat
        objects_node = re.search(r'\[node name="Objects" type="Tree" parent="([^"]*)"\]', scene_content)
        if objects_node:
            parent = objects_node.group(1)
            print(f"✅ Tree 'Objects' găsit cu parent: '{parent}'")
            
            # Extrage proprietățile tree-ului
            objects_section_start = scene_content.find('[node name="Objects"')
            next_node_start = scene_content.find('[node name=', objects_section_start + 1)
            if next_node_start == -1:
                next_node_start = len(scene_content)
            
            objects_section = scene_content[objects_section_start:next_node_start]
            print("📊 Proprietăți Tree Objects:")
            for line in objects_section.split('\n')[1:]:  # Skip primul [node name=...]
                if line.strip() and not line.startswith('['):
                    print(f"   {line}")
        else:
            print("❌ Tree 'Objects' nu a fost găsit în scenă!")
        
        print()
    else:
        print(f"❌ Fișier scenă nu a fost găsit: {scene_file}")
        return False
    
    return True

def check_gd_script_structure():
    """Verifică structura script-ului GD pentru probleme potențiale"""
    
    print("📜 VERIFICARE STRUCTURĂ SCRIPT GD:")
    
    script_file = "cad_viewer_3d.gd"
    if not os.path.exists(script_file):
        print(f"❌ Script nu a fost găsit: {script_file}")
        return False
    
    with open(script_file, 'r', encoding='utf-8') as f:
        script_content = f.read()
    
    # Verifică funcțiile cheie pentru toggle
    key_functions = [
        "_on_tree_item_edited",
        "_set_visibility_file", 
        "_set_visibility_group",
        "_set_visibility_element"
    ]
    
    for func_name in key_functions:
        if f"func {func_name}(" in script_content:
            print(f"✅ Funcția '{func_name}' găsită")
        else:
            print(f"❌ Funcția '{func_name}' LIPSEȘTE!")
    
    # Verifică conectarea semnalelor
    tree_connections = [
        'tree_node.connect("item_edited"',
        'tree_node.connect("item_selected"'
    ]
    
    print("\n📡 VERIFICARE CONECTĂRI SEMNALE:")
    for connection in tree_connections:
        if connection in script_content:
            print(f"✅ Conexiune găsită: {connection}")
        else:
            print(f"❌ Conexiune LIPSEȘTE: {connection}")
    
    # Verifică referințele la tree node
    tree_references = re.findall(r'get_node[^(]*\(["\']([^"\']*Objects[^"\']*)["\']', script_content)
    print(f"\n🔗 REFERINȚE LA TREE NODE:")
    if tree_references:
        for ref in set(tree_references):
            print(f"   - {ref}")
    else:
        print("   ❌ Nu s-au găsit referințe explicite la Objects!")
    
    # Caută probleme comune
    print(f"\n⚠️ VERIFICARE PROBLEME COMUNE:")
    
    # Verifică dacă există code duplicat sau funcții care se suprapun
    if script_content.count("func _on_tree_item_edited") > 1:
        print("❌ Funcția '_on_tree_item_edited' este definită de mai multe ori!")
    else:
        print("✅ Funcția '_on_tree_item_edited' este definită o singură dată")
    
    # Verifică dacă există probleme cu get_node_or_null
    if 'get_node_or_null("Objects")' in script_content:
        print('✅ Folosește get_node_or_null("Objects") - corect')
    elif 'get_node("Objects")' in script_content:
        print('⚠️ Folosește get_node("Objects") - poate cauza crash dacă node-ul nu există')
    else:
        print('❌ Nu folosește nicio metodă standard pentru a obține tree node-ul')
    
    return True

def suggest_fixes():
    """Sugerează soluții pentru problemele identificate"""
    
    print("\n🔧 === SOLUȚII RECOMANDATE ===")
    
    print("""
1. VERIFICĂ CONECTAREA SEMNALELOR:
   - Asigură-te că în _ready() există:
     tree_node.connect("item_edited", Callable(self, "_on_tree_item_edited"))

2. VERIFICĂ REFERINȚA LA TREE:
   - Path-ul ar trebui să fie: get_node_or_null("Objects")
   - Nu "CanvasLayer/Objects" sau alt path

3. TESTEAZĂ MANUAL:
   - Adaugă print() în _on_tree_item_edited() pentru debug
   - Verifică că funcția se apelează când faci click pe checkbox

4. VERIFICĂ GODOT 4 COMPATIBILITY:
   - TreeItem.CELL_MODE_CHECK ar trebui să fie valid
   - Callable(self, "function_name") pentru conectări

5. VERIFICĂ IMPORTED_PROJECTS:
   - Asigură-te că imported_projects conține datele corecte
   - Verifică că key-urile din metadata corespund cu imported_projects

6. GODOT CONSOLE OUTPUT:
   - Rulează scena și verifică output-ul în consolă
   - Caută erori sau warning-uri legate de tree sau conexiuni
""")

def main():
    """Funcția principală de verificare"""
    
    scene_ok = check_tree_configuration()
    script_ok = check_gd_script_structure() if scene_ok else False
    
    if scene_ok and script_ok:
        print("\n🎯 DIAGNOSTICARE COMPLETĂ - verifică soluțiile recomandate")
    else:
        print("\n❌ S-AU GĂSIT PROBLEME STRUCTURALE - corectează-le mai întâi")
    
    suggest_fixes()

if __name__ == "__main__":
    main()