#!/usr/bin/env python3
"""
Mini-test pentru a simula procesarea IfcSpace cu Opening_area
"""

# Simulează funcția evaluate_math_formula implementată
import re

def evaluate_math_formula(formula_str):
    if not formula_str or not isinstance(formula_str, str):
        return 0.0
    
    formula = formula_str.strip()
    if formula.startswith('='):
        formula = formula[1:]
    
    if not re.match(r'^[\d\.\+\-\*\/\(\)\s]+$', formula):
        print(f"[DEBUG] Formula Opening_area conține caractere nepermise: {formula_str}")
        return 0.0
    
    try:
        result = eval(formula, {"__builtins__": {}}, {})
        if isinstance(result, (int, float)):
            print(f"[DEBUG] Formula Opening_area evaluată: '{formula_str}' = {result}")
            return float(result)
        else:
            return 0.0
    except Exception as e:
        print(f"[DEBUG] Eroare la evaluarea formulei Opening_area '{formula_str}': {e}")
        return 0.0

# Simulează procesarea unei entități IfcSpace
def simulate_ifcspace_processing():
    print("=== Simulare procesare IfcSpace cu Opening_area ===")
    
    # Date simulate pentru o cameră IfcSpace
    layer = "IfcSpace"
    mesh_name = "IfcSpace_wall_Camera1_1"
    opening_area_formula = "=2.1*0.9+1.2*1.2"  # Două ferestre
    height = 2.8  # înălțimea camerei
    perimeter = 20.0  # perimetrul camerei
    
    # Calculez lateral_area original
    lateral_area = perimeter * height
    print(f"Camera: {mesh_name}")
    print(f"Perimetru: {perimeter}m, Înălțime: {height}m")
    print(f"Lateral area originală: {lateral_area}m²")
    print(f"Opening_area formula: {opening_area_formula}")
    
    # Aplică ajustarea pentru IfcSpace
    if layer == "IfcSpace" and opening_area_formula:
        opening_area_value = evaluate_math_formula(opening_area_formula)
        if opening_area_value > 0:
            lateral_area = max(0.0, lateral_area - opening_area_value)
            print(f"[DEBUG] IfcSpace {mesh_name}: lateral_area ajustată cu Opening_area={opening_area_value:.2f}, lateral_area finală={lateral_area:.2f}")
    
    print(f"Lateral area finală: {lateral_area}m²")
    print(f"Suprafața scăzută (ferestre/uși): {perimeter * height - lateral_area:.2f}m²")

if __name__ == "__main__":
    simulate_ifcspace_processing()