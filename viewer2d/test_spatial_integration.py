import sys
import os
sys.path.append(os.path.join(os.path.dirname(__file__), 'python'))

from dxf_to_glb_trimesh import dxf_to_gltf

# Test cu un fișier DXF care conține cercuri de control
test_dxf = "C:/Users/ionut.ciuntuc/Desktop/1SecondFloor.dxf"
test_output = "C:/Users/ionut.ciuntuc/Documents/viewer2d/test_spatial.glb"

if os.path.exists(test_dxf):
    print("="*60)
    print("TEST INTEGRARE FORME SPAȚIALE")
    print("="*60)
    
    try:
        dxf_to_gltf(test_dxf, test_output, arc_segments=16)
        print(f"\n✅ Test reușit! Output: {test_output}")
    except Exception as e:
        print(f"\n❌ Test eșuat: {e}")
        import traceback
        traceback.print_exc()
else:
    print(f"❌ Fișier DXF test nu există: {test_dxf}")