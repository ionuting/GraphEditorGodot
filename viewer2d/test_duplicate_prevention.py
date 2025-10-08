#!/usr/bin/env python3
"""
Test pentru verificarea eliminării duplicatelor în exportul IfcSpace
Simulează scenarii cu noduri duplicate pentru a testa logica corectată
"""

def simulate_godot_node_search():
    """Simulează căutarea nodurilor în Godot pentru a testa logica anti-duplicate"""
    
    print("🔍 === TEST ELIMINARE DUPLICATE IfcSpace ===\n")
    
    # Simulează noduri cu diferite caracteristici
    class MockNode:
        def __init__(self, name, is_mesh=True, layer_meta=None):
            self.name = name
            self.is_mesh = is_mesh
            self.layer_meta = layer_meta
        
        def is_MeshInstance3D(self):
            return self.is_mesh
        
        def has_meta(self, key):
            return key == "layer" and self.layer_meta is not None
        
        def get_meta(self, key):
            if key == "layer":
                return self.layer_meta
            return None
        
        def __str__(self):
            return self.name
        
        def __eq__(self, other):
            return isinstance(other, MockNode) and self.name == other.name
    
    # Simulează noduri din scenă
    test_nodes = [
        # Caz 1: Nod cu metadata layer="IfcSpace" și nume care conține "IfcSpace" - POATE CAUZA DUPLICATE
        MockNode("IfcSpace_LivingRoom_1_LAYER_IfcSpace", True, "IfcSpace"),
        
        # Caz 2: Nod doar cu numele care conține "IfcSpace" (fără metadata)
        MockNode("IfcSpace_Kitchen_1_LAYER_IfcSpace", True, None),
        
        # Caz 3: Nod cu metadata layer="IfcSpace" dar nume fără "IfcSpace"
        MockNode("Room_Bedroom_1", True, "IfcSpace"),
        
        # Caz 4: Nod care nu este MeshInstance3D - AR TREBUI IGNORAT
        MockNode("IfcSpace_SomeOtherNode", False, "IfcSpace"),
        
        # Caz 5: Nod cu alt tip de layer - AR TREBUI IGNORAT
        MockNode("IfcWall_Wall_1", True, "IfcWall"),
        
        # Caz 6: Nod identic cu primul (pentru a testa verificarea duplicate în array)
        MockNode("IfcSpace_LivingRoom_1_LAYER_IfcSpace", True, "IfcSpace"),
    ]
    
    # Simulează logica corectată
    def find_ifcspace_nodes_corrected(nodes):
        space_nodes = []
        
        for node in nodes:
            is_ifcspace = False
            
            # Verifică dacă nodul curent este un MeshInstance3D
            if node.is_MeshInstance3D():
                # Prioritate 1: Verifică metadata layer
                if node.has_meta("layer"):
                    layer = node.get_meta("layer")
                    if layer == "IfcSpace":
                        is_ifcspace = True
                        print(f"[DEBUG] Found IfcSpace by metadata: {node.name}")
                
                # Prioritate 2: Verifică numele nodului doar dacă nu a fost găsit prin metadata
                elif "IfcSpace" in str(node.name):
                    is_ifcspace = True
                    print(f"[DEBUG] Found IfcSpace by name: {node.name}")
                
                # Adaugă nodul doar o singură dată
                if is_ifcspace:
                    # Verifică dacă nodul nu există deja în array (pentru siguranță extra)
                    if node not in space_nodes:
                        space_nodes.append(node)
                        print(f"[DEBUG] Added IfcSpace node: {node.name}")
                    else:
                        print(f"[WARNING] Prevented duplicate IfcSpace node: {node.name}")
            else:
                if "IfcSpace" in str(node.name):
                    print(f"[DEBUG] Skipped non-MeshInstance3D node: {node.name}")
        
        return space_nodes
    
    # Simulează logica veche (cu probleme)
    def find_ifcspace_nodes_old(nodes):
        space_nodes = []
        
        for node in nodes:
            # Verifică dacă nodul curent este un MeshInstance3D cu metadata IfcSpace
            if node.is_MeshInstance3D() and node.has_meta("layer"):
                layer = node.get_meta("layer")
                if layer == "IfcSpace":
                    space_nodes.append(node)
                    print(f"[OLD] Found IfcSpace node: {node.name}")
            
            # Caută și în numele nodului pentru IfcSpace
            if "IfcSpace" in str(node.name):
                if node.is_MeshInstance3D():
                    space_nodes.append(node)
                    print(f"[OLD] Found IfcSpace by name: {node.name}")
        
        return space_nodes
    
    # Testează logica veche
    print("📊 TESTARE LOGICĂ VECHE (cu duplicate):")
    old_nodes = find_ifcspace_nodes_old(test_nodes)
    print(f"Noduri găsite (logica veche): {len(old_nodes)}")
    old_names = [str(node) for node in old_nodes]
    duplicate_count_old = len(old_names) - len(set(old_names))
    print(f"Duplicate detectate: {duplicate_count_old}")
    print()
    
    # Testează logica nouă
    print("📊 TESTARE LOGICĂ NOUĂ (fără duplicate):")
    new_nodes = find_ifcspace_nodes_corrected(test_nodes)
    print(f"Noduri găsite (logica nouă): {len(new_nodes)}")
    new_names = [str(node) for node in new_nodes]
    duplicate_count_new = len(new_names) - len(set(new_names))
    print(f"Duplicate detectate: {duplicate_count_new}")
    print()
    
    # Rezultate
    print("🎯 REZULTATE COMPARAȚIE:")
    print(f"Logica veche: {len(old_nodes)} noduri, {duplicate_count_old} duplicate")
    print(f"Logica nouă: {len(new_nodes)} noduri, {duplicate_count_new} duplicate")
    
    improvement = len(old_nodes) - len(new_nodes)
    print(f"Îmbunătățire: {'✅ Eliminate ' + str(improvement) + ' duplicate' if improvement > 0 else '⚠️ Nu s-au eliminat duplicate'}")
    
    # Lista finală de noduri
    print(f"\n📋 NODURI FINALE GĂSITE:")
    for i, node in enumerate(new_nodes, 1):
        meta_info = f" (metadata: {node.get_meta('layer')})" if node.has_meta("layer") else " (doar nume)"
        print(f"  {i}. {node.name}{meta_info}")

if __name__ == "__main__":
    simulate_godot_node_search()