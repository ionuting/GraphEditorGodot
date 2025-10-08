#!/usr/bin/env python3
"""
Test pentru funcția de evaluare a formulelor Opening_area
"""

import re

def evaluate_math_formula(formula_str):
    """
    Evaluează o formulă matematică de tip '=2.1*0.9+1.2*1.2'
    Returnează valoarea calculată sau 0.0 în caz de eroare.
    """
    if not formula_str or not isinstance(formula_str, str):
        return 0.0
    
    # Elimină spațiile și semnul '=' de la început
    formula = formula_str.strip()
    if formula.startswith('='):
        formula = formula[1:]
    
    # Verifică că formula conține doar caractere sigure pentru evaluare matematică
    # Permite doar cifre, puncte, +, -, *, /, paranteze și spații
    if not re.match(r'^[\d\.\+\-\*\/\(\)\s]+$', formula):
        print(f"[DEBUG] Formula Opening_area conține caractere nepermise: {formula_str}")
        return 0.0
    
    try:
        # Evaluează formula într-un context restricționat
        result = eval(formula, {"__builtins__": {}}, {})
        if isinstance(result, (int, float)):
            print(f"[DEBUG] Formula Opening_area evaluată: '{formula_str}' = {result}")
            return float(result)
        else:
            print(f"[DEBUG] Formula Opening_area nu returnează un număr: {formula_str}")
            return 0.0
    except Exception as e:
        print(f"[DEBUG] Eroare la evaluarea formulei Opening_area '{formula_str}': {e}")
        return 0.0

# Test cases
if __name__ == "__main__":
    print("=== Test Opening_area Formula Evaluation ===")
    
    test_cases = [
        "=2.1*0.9+1.2*1.2",
        "=2.5*1.8",
        "=(1.5+2.0)*0.8",
        "=10.0-3.5+2.1",
        "=2.0/0.5",
        "=(2.0+3.0)*(1.5-0.5)",
        "2.1*0.9+1.2*1.2",  # fără =
        "=invalid_formula",  # invalid
        "=2.0++1.0",  # sintaxă invalidă
        "",  # gol
        None,  # None
        "=2.0*abc",  # variabile nepermise
    ]
    
    for i, formula in enumerate(test_cases, 1):
        print(f"\nTest {i}: {formula}")
        result = evaluate_math_formula(formula)
        print(f"Rezultat: {result}")
        
        # Verificare manuală pentru primul test
        if i == 1:
            expected = 2.1 * 0.9 + 1.2 * 1.2
            print(f"Expected: {expected}")
            print(f"Match: {abs(result - expected) < 0.0001}")