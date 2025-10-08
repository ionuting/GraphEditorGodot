#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import json

# Load mapping and check column Z values
with open('test_window_materials_mapping.json', 'r', encoding='utf-8') as f:
    data = json.load(f)

print("Column Z Analysis:")
print("-" * 50)

# Find columns by mesh_name
columns_found = 0
for entry in data:
    mesh_name = entry.get('mesh_name', '')
    if 'column' in mesh_name.lower():
        columns_found += 1
        name = entry.get('name', 'no_name')
        ifc_type = entry.get('ifc_type', '')
        z_pos = entry.get('insert_position', {}).get('z', 'N/A')
        height = entry.get('height', 'N/A')
        
        print(f"{mesh_name}:")
        print(f"  Name: {name}")
        print(f"  IFC Type: {ifc_type}")
        print(f"  Z Global: {z_pos}")
        print(f"  Height: {height}")
        if isinstance(z_pos, (int, float)) and isinstance(height, (int, float)):
            print(f"  Current Z range: {z_pos:.3f} to {z_pos + height:.3f}")
            print(f"  Correct Z range: 0.000 to {height:.3f}")
        print()

print(f"Found {columns_found} columns total")