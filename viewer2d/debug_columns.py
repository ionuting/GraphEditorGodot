#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import json
import trimesh
import ifcopenshell
import sys
import os

def debug_column_geometry():
    """Debug column geometry issues"""
    
    # Load mapping file
    mapping_file = 'test_window_materials_mapping.json'
    if not os.path.exists(mapping_file):
        print(f"Mapping file {mapping_file} not found")
        return
        
    try:
        with open(mapping_file, 'r', encoding='utf-8') as f:
            mapping = json.load(f)
    except Exception as e:
        print(f"Error loading mapping: {e}")
        return
    
    # Find column entries
    columns = []
    for entry in mapping:
        ifc_type = entry.get('ifc_type', '')
        name = entry.get('name', '')
        if 'IfcColumn' in ifc_type or 'column' in name.lower():
            columns.append(entry)
    
    print(f"Found {len(columns)} columns in mapping:")
    print("-" * 60)
    
    for i, col in enumerate(columns[:5]):  # Show first 5
        print(f"Column {i+1}:")
        print(f"  Name: {col.get('name', 'unknown')}")
        print(f"  IFC Type: {col.get('ifc_type', 'unknown')}")
        print(f"  Height: {col.get('height', 'N/A')}")
        
        insert_pos = col.get('insert_position', {})
        print(f"  Insert Position Z: {insert_pos.get('z', 'N/A')}")
        
        print(f"  Volume: {col.get('volume', 'N/A')}")
        print(f"  Area: {col.get('area', 'N/A')}")
        print(f"  Lateral Area: {col.get('lateral_area', 'N/A')}")
        
        # Check vertices to see Z extent
        vertices = col.get('vertices', [])
        if vertices:
            print(f"  Vertices count: {len(vertices)}")
            # Note: vertices are 2D in mapping, 3D info is in height and z
        
        print()
    
    # Load GLB to check actual mesh geometry
    glb_file = 'test_window_materials.glb'
    if os.path.exists(glb_file):
        print("\nChecking GLB mesh geometry:")
        print("-" * 60)
        
        try:
            scene = trimesh.load(glb_file)
            if hasattr(scene, 'geometry'):
                meshes = scene.geometry
            else:
                meshes = [scene] if hasattr(scene, 'vertices') else []
            
            column_meshes = []
            for mesh_name, mesh in meshes.items():
                if 'column' in mesh_name.lower():
                    column_meshes.append((mesh_name, mesh))
            
            print(f"Found {len(column_meshes)} column meshes in GLB:")
            
            for mesh_name, mesh in column_meshes[:3]:  # Show first 3
                bounds = mesh.bounds
                z_min, z_max = bounds[0][2], bounds[1][2]
                z_height = z_max - z_min
                
                print(f"  {mesh_name}:")
                print(f"    Z bounds: {z_min:.3f} to {z_max:.3f}")
                print(f"    Z height: {z_height:.3f}")
                print(f"    Vertices: {len(mesh.vertices)}")
                print(f"    Faces: {len(mesh.faces)}")
                print()
                
        except Exception as e:
            print(f"Error loading GLB: {e}")
    
    # Load IFC to check final geometry
    ifc_file = 'test_window_materials_from_glb.ifc'
    if os.path.exists(ifc_file):
        print("\nChecking IFC geometry:")
        print("-" * 60)
        
        try:
            ifc = ifcopenshell.open(ifc_file)
            columns_ifc = ifc.by_type('IfcColumn')
            
            print(f"Found {len(columns_ifc)} columns in IFC:")
            
            for i, col in enumerate(columns_ifc[:3]):  # Show first 3
                print(f"  Column {i+1}: {col.Name}")
                
                if col.Representation and col.Representation.Representations:
                    for rep in col.Representation.Representations:
                        if rep.Items:
                            for item in rep.Items:
                                if item.is_a('IfcTriangulatedFaceSet'):
                                    coords = item.Coordinates
                                    if coords and coords.CoordList:
                                        coord_list = coords.CoordList
                                        z_coords = [coord[2] for coord in coord_list]
                                        z_min_ifc = min(z_coords)
                                        z_max_ifc = max(z_coords)
                                        z_height_ifc = z_max_ifc - z_min_ifc
                                        
                                        print(f"    IFC Z bounds: {z_min_ifc:.3f} to {z_max_ifc:.3f}")
                                        print(f"    IFC Z height: {z_height_ifc:.3f}")
                                        print(f"    IFC Coordinates: {len(coord_list)}")
                print()
                        
        except Exception as e:
            print(f"Error loading IFC: {e}")

if __name__ == "__main__":
    debug_column_geometry()