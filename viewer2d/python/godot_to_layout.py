#!/usr/bin/env python3
"""
Godot to Layout Generator Bridge
Convertește datele din aplicația Godot Viewer2D la format compatibil cu Layout Generator
"""

import json
import sys
import os
from pathlib import Path
import trimesh
import numpy as np

class GodotToLayoutConverter:
    def __init__(self):
        self.shapes = []
        self.meshes = []
        
    def load_from_godot_json(self, json_path):
        """Încarcă datele din JSON-ul generat de aplicația Godot"""
        try:
            with open(json_path, 'r', encoding='utf-8') as f:
                data = json.load(f)
            
            self.shapes = data.get('shapes', [])
            print(f"Loaded {len(self.shapes)} shapes from Godot")
            return True
            
        except Exception as e:
            print(f"Error loading Godot JSON: {e}")
            return False
    
    def convert_to_glb_format(self):
        """Convertește shape-urile Godot în mesh-uri 3D pentru Layout Generator"""
        scene = trimesh.Scene()
        metadata = []
        
        for i, shape in enumerate(self.shapes):
            # Extrage informațiile din shape-ul Godot
            shape_type = shape.get('type', 'rectangle')
            position = shape.get('position', {'x': 0, 'y': 0})
            size = shape.get('size', {'x': 1, 'y': 1})
            
            # Creează mesh 3D din shape-ul 2D
            mesh = self.create_mesh_from_shape(shape_type, position, size)
            
            if mesh:
                mesh_name = f"shape_{i}_{shape_type}"
                scene.add_geometry(mesh, node_name=mesh_name)
                
                # Creează metadata pentru Layout Generator
                metadata_entry = {
                    "name": mesh_name,
                    "mesh_name": mesh_name,  # Adaugă și mesh_name pentru compatibilitate
                    "uuid": f"godot-{i:04d}",
                    "type": shape_type,
                    "material": shape.get('material', 'default'),
                    "layer": shape.get('layer', 'default'),
                    "properties": {
                        "position": position,
                        "size": size,
                        "original_shape": shape
                    }
                }
                metadata.append(metadata_entry)
        
        return scene, metadata
    
    def create_mesh_from_shape(self, shape_type, position, size):
        """Creează un mesh 3D din parametrii shape-ului Godot"""
        if shape_type == 'rectangle':
            return self.create_rectangle_mesh(position, size)
        elif shape_type == 'wall':
            return self.create_wall_mesh(position, size)
        elif shape_type == 'door':
            return self.create_door_mesh(position, size)
        elif shape_type == 'window':
            return self.create_window_mesh(position, size)
        else:
            # Default rectangle pentru tipuri necunoscute
            return self.create_rectangle_mesh(position, size)
    
    def create_rectangle_mesh(self, position, size):
        """Creează un mesh rectangular"""
        x, y = position['x'], position['y']
        w, h = size['x'], size['y']
        
        # Definește vârfurile unui dreptunghi 3D (extrudat pe Z)
        vertices = np.array([
            [x, y, 0],      # bottom-left-back
            [x+w, y, 0],    # bottom-right-back
            [x+w, y+h, 0],  # top-right-back
            [x, y+h, 0],    # top-left-back
            [x, y, 0.1],    # bottom-left-front (înălțime mică)
            [x+w, y, 0.1],  # bottom-right-front
            [x+w, y+h, 0.1],# top-right-front
            [x, y+h, 0.1],  # top-left-front
        ])
        
        # Definește fețele (orientate counter-clockwise)
        faces = np.array([
            [0, 1, 2], [0, 2, 3],  # bottom face
            [4, 7, 6], [4, 6, 5],  # top face
            [0, 4, 5], [0, 5, 1],  # front face
            [2, 6, 7], [2, 7, 3],  # back face
            [0, 3, 7], [0, 7, 4],  # left face
            [1, 5, 6], [1, 6, 2],  # right face
        ])
        
        return trimesh.Trimesh(vertices=vertices, faces=faces)
    
    def create_wall_mesh(self, position, size):
        """Creează un mesh pentru un perete (mai înalt)"""
        x, y = position['x'], position['y']
        w, h = size['x'], size['y']
        wall_height = 2.8  # Înălțime standard perete
        
        vertices = np.array([
            [x, y, 0],      
            [x+w, y, 0],    
            [x+w, y+h, 0],  
            [x, y+h, 0],    
            [x, y, wall_height],      
            [x+w, y, wall_height],    
            [x+w, y+h, wall_height],  
            [x, y+h, wall_height],    
        ])
        
        faces = np.array([
            [0, 1, 2], [0, 2, 3],  # bottom
            [4, 7, 6], [4, 6, 5],  # top
            [0, 4, 5], [0, 5, 1],  # front
            [2, 6, 7], [2, 7, 3],  # back
            [0, 3, 7], [0, 7, 4],  # left
            [1, 5, 6], [1, 6, 2],  # right
        ])
        
        return trimesh.Trimesh(vertices=vertices, faces=faces)
    
    def create_door_mesh(self, position, size):
        """Creează un mesh pentru o ușă"""
        # Similar cu wall dar cu înălțime de ușă (2.1m)
        x, y = position['x'], position['y']
        w, h = size['x'], size['y']
        door_height = 2.1
        
        vertices = np.array([
            [x, y, 0], [x+w, y, 0], [x+w, y+h, 0], [x, y+h, 0],
            [x, y, door_height], [x+w, y, door_height], 
            [x+w, y+h, door_height], [x, y+h, door_height],
        ])
        
        faces = np.array([
            [0, 1, 2], [0, 2, 3], [4, 7, 6], [4, 6, 5],
            [0, 4, 5], [0, 5, 1], [2, 6, 7], [2, 7, 3],
            [0, 3, 7], [0, 7, 4], [1, 5, 6], [1, 6, 2],
        ])
        
        return trimesh.Trimesh(vertices=vertices, faces=faces)
    
    def create_window_mesh(self, position, size):
        """Creează un mesh pentru o fereastră"""
        # Fereastră cu poziție înălțată (0.9m de la sol)
        x, y = position['x'], position['y']
        w, h = size['x'], size['y']
        window_bottom = 0.9
        window_height = 1.2
        
        vertices = np.array([
            [x, y, window_bottom], [x+w, y, window_bottom], 
            [x+w, y+h, window_bottom], [x, y+h, window_bottom],
            [x, y, window_bottom + window_height], [x+w, y, window_bottom + window_height], 
            [x+w, y+h, window_bottom + window_height], [x, y+h, window_bottom + window_height],
        ])
        
        faces = np.array([
            [0, 1, 2], [0, 2, 3], [4, 7, 6], [4, 6, 5],
            [0, 4, 5], [0, 5, 1], [2, 6, 7], [2, 7, 3],
            [0, 3, 7], [0, 7, 4], [1, 5, 6], [1, 6, 2],
        ])
        
        return trimesh.Trimesh(vertices=vertices, faces=faces)
    
    def export_for_layout_generator(self, base_name):
        """Exportă în formatul necesar pentru Layout Generator"""
        scene, metadata = self.convert_to_glb_format()
        
        if not scene.geometry:
            print("No geometry to export!")
            return False
        
        # Salvează GLB
        glb_path = f"{base_name}.glb"
        scene.export(glb_path)
        print(f"Exported GLB: {glb_path}")
        
        # Salvează metadata JSON
        json_path = f"{base_name}_mapping.json"
        with open(json_path, 'w', encoding='utf-8') as f:
            json.dump(metadata, f, indent=2, ensure_ascii=False)
        print(f"Exported metadata: {json_path}")
        
        return True

def main():
    if len(sys.argv) < 2:
        print("Usage: python godot_to_layout.py <godot_json_path> [output_base_name]")
        print("Example: python godot_to_layout.py temp_project.json my_project")
        return
    
    json_path = sys.argv[1]
    base_name = sys.argv[2] if len(sys.argv) > 2 else "godot_export"
    
    if not os.path.exists(json_path):
        print(f"Error: File {json_path} not found!")
        return
    
    converter = GodotToLayoutConverter()
    
    print(f"Loading Godot project from {json_path}...")
    if not converter.load_from_godot_json(json_path):
        return
    
    print(f"Converting to Layout Generator format...")
    if converter.export_for_layout_generator(base_name):
        print(f"\nSuccess! Files generated:")
        print(f"  - {base_name}.glb")
        print(f"  - {base_name}_mapping.json")
        print(f"\nNow you can generate layouts with:")
        print(f"  python python/layout_generator.py {base_name}")
    else:
        print("Export failed!")

if __name__ == "__main__":
    main()