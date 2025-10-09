#!/usr/bin/env python
"""
Calculează și compară factorii de zoom pentru diferite sensibilități
"""

def compare_zoom_factors():
    """
    Compară factorii de zoom între valorile vechi și noi
    """
    print("📐 Comparație Factori de Zoom")
    print("=" * 40)
    
    # Valorile zoom
    old_zoom = 1.1
    new_zoom = 1.05
    
    print(f"ZOOM SPEED VECHI: {old_zoom}")
    print(f"   Zoom In (scroll down):  +{(old_zoom-1)*100:.1f}%")
    print(f"   Zoom Out (scroll up):   -{(1-1/old_zoom)*100:.1f}%")
    
    print(f"\nZOOM SPEED NOU: {new_zoom}")
    print(f"   Zoom In (scroll down):  +{(new_zoom-1)*100:.1f}%")
    print(f"   Zoom Out (scroll up):   -{(1-1/new_zoom)*100:.1f}%")
    
    print(f"\n🔄 REDUCEREA SENSIBILITĂȚII:")
    reduction_in = ((old_zoom-1) - (new_zoom-1)) / (old_zoom-1) * 100
    reduction_out = ((1-1/old_zoom) - (1-1/new_zoom)) / (1-1/old_zoom) * 100
    print(f"   Zoom In:  {reduction_in:.1f}% mai puțin sensibil")
    print(f"   Zoom Out: {reduction_out:.1f}% mai puțin sensibil")
    
    print(f"\n📊 EXEMPLE PRACTICE:")
    print("   Cu 10 scroll-uri consecutive:")
    
    # 10 zoom in consecutive
    old_result_in = old_zoom ** 10
    new_result_in = new_zoom ** 10
    print(f"   ÎNAINTE - Zoom In x10:  {old_result_in:.2f}x mărire")
    print(f"   ACUM   - Zoom In x10:  {new_result_in:.2f}x mărire")
    
    # 10 zoom out consecutive  
    old_result_out = (1/old_zoom) ** 10
    new_result_out = (1/new_zoom) ** 10
    print(f"   ÎNAINTE - Zoom Out x10: {old_result_out:.2f}x micșorare")
    print(f"   ACUM   - Zoom Out x10: {new_result_out:.2f}x micșorare")
    
    print(f"\n🎯 CONCLUZIE:")
    print("   Zoom-ul este acum mult mai controlabil!")
    print("   Perfect pentru lucrul de precizie în CAD.")

if __name__ == "__main__":
    compare_zoom_factors()