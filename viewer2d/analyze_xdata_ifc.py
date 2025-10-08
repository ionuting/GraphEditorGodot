#!/usr/bin/env python3
import ifcopenshell
import sys

def analyze_ifc_xdata():
    print('🔍 ANALIZĂ DETALIATĂ IFC CU XDATA')
    print('=' * 45)

    try:
        model = ifcopenshell.open('test_xdata_spaces.ifc')
        spaces = model.by_type('IfcSpace')
        
        print(f'📊 Numărul de spații găsite: {len(spaces)}')
        
        for i, space in enumerate(spaces, 1):
            name = space.Name or f'Space_{i}'
            print(f'\n🏠 SPACE {i}: {name}')
            print(f'   GlobalId: {space.GlobalId}')
            
            # Verifică toate relațiile IsDefinedBy
            print(f'   📋 Relații IsDefinedBy: {len(space.IsDefinedBy)}')
            
            for j, rel in enumerate(space.IsDefinedBy):
                print(f'      Relație {j+1}: {type(rel).__name__}')
                
                if hasattr(rel, 'RelatingPropertyDefinition'):
                    pset = rel.RelatingPropertyDefinition
                    pset_name = getattr(pset, 'Name', 'Unknown')
                    print(f'         PropertySet: {pset_name}')
                    
                    if hasattr(pset, 'HasProperties'):
                        print(f'         Proprietăți: {len(pset.HasProperties)}')
                        
                        for prop in pset.HasProperties:
                            prop_name = getattr(prop, 'Name', 'Unknown')
                            prop_type = type(prop).__name__
                            
                            value = 'N/A'
                            if hasattr(prop, 'NominalValue') and prop.NominalValue:
                                value = prop.NominalValue.wrappedValue
                            
                            print(f'            - {prop_name} ({prop_type}): {value}')
                            
                            # Verifică special pentru LateralArea
                            if prop_name == 'LateralArea' and name == 'TestSpace_WithXDATA':
                                print(f'            🔧 ACEASTA ESTE LATERAL AREA CU XDATA!')
                                expected = 50.0 - 3.33  # 46.67
                                if isinstance(value, (int, float)):
                                    if abs(value - expected) < 0.1:
                                        print(f'            ✅ Valoarea este corectă! {value} ≈ {expected:.2f}')
                                    else:
                                        print(f'            ❌ Valoarea pare incorectă {value} != {expected:.2f}')
                                else:
                                    print(f'            ⚠️ Valoarea nu este numerică: {value}')
            
            # Verifică și proprietățile standard
            print(f'   📐 Proprietăți geometrice standard:')
            if hasattr(space, 'ObjectType'):
                print(f'      ObjectType: {space.ObjectType}')
            if hasattr(space, 'LongName'):
                print(f'      LongName: {space.LongName}')
            if hasattr(space, 'PredefinedType'):
                print(f'      PredefinedType: {space.PredefinedType}')
        
        # Verifică toate PropertySets din model
        print(f'\n📋 TOATE PROPERTY SETS ÎN MODEL:')
        all_psets = model.by_type('IfcPropertySet')
        print(f'   Numărul total de PropertySets: {len(all_psets)}')
        
        for pset in all_psets:
            pset_name = getattr(pset, 'Name', 'Unknown')
            prop_count = len(getattr(pset, 'HasProperties', []))
            print(f'   - {pset_name}: {prop_count} proprietăți')
        
    except Exception as e:
        print(f'❌ Eroare la analiza IFC: {e}')
        import traceback
        traceback.print_exc()

if __name__ == '__main__':
    analyze_ifc_xdata()