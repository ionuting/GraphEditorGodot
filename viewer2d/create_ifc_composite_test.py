#!/usr/bin/env python3
"""
Creează un DXF de test pentru regula IfcType cu componente pe layere diferite.
Layer bloc = IfcType (IfcWindow)
Layere componente = materiale (wood, glass, steel)
XDATA pe bloc = poziție Z, rotații X/Y
"""
import ezdxf

def create_ifc_composite_test():
    # Creează un document DXF nou
    doc = ezdxf.new('R2010')
    msp = doc.modelspace()
    
    # 1. Creează un bloc IfcWindow cu componente pe layere diferite
    window_block = doc.blocks.new(name='Window_120x80')
    
    # Componenta 1: Rama din lemn
    frame_outer = window_block.add_lwpolyline([
        (0, 0), (1.2, 0), (1.2, 0.8), (0, 0.8)
    ], close=True)
    frame_outer.dxf.layer = "wood"  # Layer pentru material lemn
    frame_outer.set_xdata('QCAD', [
        (1000, "height:0.1"),       # Grosimea ramei
        (1000, "Name:Frame"),       # Numele componentei
        (1000, "solid:1")           # Solid
    ])
    
    # Componenta 2: Sticla (panoul interior)
    glass_panel = window_block.add_lwpolyline([
        (0.05, 0.05), (1.15, 0.05), (1.15, 0.75), (0.05, 0.75)
    ], close=True)
    glass_panel.dxf.layer = "glass"  # Layer pentru material sticlă
    glass_panel.set_xdata('QCAD', [
        (1000, "height:0.02"),      # Grosimea sticlei
        (1000, "Name:GlassPanel"),  # Numele componentei
        (1000, "solid:1")           # Solid
    ])
    
    # Componenta 3: Mâner din metal
    handle = window_block.add_circle((1.1, 0.4), 0.03)
    handle.dxf.layer = "steel"  # Layer pentru material metal
    handle.set_xdata('QCAD', [
        (1000, "height:0.05"),      # Grosimea mânerului
        (1000, "Name:Handle"),      # Numele componentei
        (1000, "solid:1")           # Solid
    ])
    
    # Componenta 4: Garnitură (void în ramă)
    seal = window_block.add_lwpolyline([
        (0.02, 0.02), (1.18, 0.02), (1.18, 0.78), (0.02, 0.78)
    ], close=True)
    seal.dxf.layer = "rubber"  # Layer pentru material cauciuc
    seal.set_xdata('QCAD', [
        (1000, "height:0.01"),      # Grosimea garniturii
        (1000, "Name:Seal"),        # Numele componentei
        (1000, "solid:0")           # Void (se scade din ramă)
    ])
    
    # 2. Creează un bloc IfcDoor cu componente diferite
    door_block = doc.blocks.new(name='Door_90x210')
    
    # Panoul ușii din lemn
    door_panel = door_block.add_lwpolyline([
        (0, 0), (0.9, 0), (0.9, 2.1), (0, 2.1)
    ], close=True)
    door_panel.dxf.layer = "wood"
    door_panel.set_xdata('QCAD', [
        (1000, "height:0.04"),
        (1000, "Name:DoorPanel"),
        (1000, "solid:1")
    ])
    
    # Fereastra în ușă din sticlă
    door_glass = door_block.add_lwpolyline([
        (0.2, 1.2), (0.7, 1.2), (0.7, 1.9), (0.2, 1.9)
    ], close=True)
    door_glass.dxf.layer = "glass"
    door_glass.set_xdata('QCAD', [
        (1000, "height:0.01"),
        (1000, "Name:DoorGlass"),
        (1000, "solid:1")
    ])
    
    # Mânerul ușii din metal
    door_handle = door_block.add_circle((0.8, 1.05), 0.02)
    door_handle.dxf.layer = "steel"
    door_handle.set_xdata('QCAD', [
        (1000, "height:0.06"),
        (1000, "Name:DoorHandle"),
        (1000, "solid:1")
    ])
    
    # 3. Inserează fereastra (IfcWindow) în diferite poziții
    # Fereastră orizontală (normală)
    window1 = msp.add_blockref('Window_120x80', (0, 0))
    window1.dxf.layer = "IfcWindow"  # IfcType
    window1.set_xdata('QCAD', [
        (1000, "z:1.0"),            # Înălțimea de montaj
        (1000, "rotate_x:0.0"),     # Fără rotație X
        (1000, "rotate_y:0.0")      # Fără rotație Y
    ])
    
    # Fereastră rotită vertical (pe perete)
    window2 = msp.add_blockref('Window_120x80', (3, 0))
    window2.dxf.layer = "IfcWindow"  # IfcType
    window2.set_xdata('QCAD', [
        (1000, "z:0.0"),            # La sol
        (1000, "rotate_x:90.0"),    # Rotație 90° pe X (vertical)
        (1000, "rotate_y:0.0")
    ])
    
    # Fereastră rotită pe Y (pe alt perete)
    window3 = msp.add_blockref('Window_120x80', (6, 0))
    window3.dxf.layer = "IfcWindow"  # IfcType
    window3.set_xdata('QCAD', [
        (1000, "z:0.0"),
        (1000, "rotate_x:0.0"),
        (1000, "rotate_y:90.0")     # Rotație 90° pe Y
    ])
    
    # 4. Inserează ușa (IfcDoor)
    door1 = msp.add_blockref('Door_90x210', (0, 4))
    door1.dxf.layer = "IfcDoor"  # IfcType diferit
    door1.set_xdata('QCAD', [
        (1000, "z:0.0"),            # La sol
        (1000, "rotate_x:0.0"),
        (1000, "rotate_y:0.0")
    ])
    
    # Ușă rotită
    door2 = msp.add_blockref('Door_90x210', (3, 4))
    door2.dxf.layer = "IfcDoor"  # IfcType
    door2.set_xdata('QCAD', [
        (1000, "z:0.0"),
        (1000, "rotate_x:45.0"),    # Rotație 45° pe X
        (1000, "rotate_y:30.0")     # Rotație 30° pe Y
    ])
    
    # 5. Creează un bloc IfcWall simplu pentru comparație
    wall_block = doc.blocks.new(name='Wall_200x30')
    
    # Structura din beton
    concrete_core = wall_block.add_lwpolyline([
        (0, 0), (2.0, 0), (2.0, 0.3), (0, 0.3)
    ], close=True)
    concrete_core.dxf.layer = "concrete"
    concrete_core.set_xdata('QCAD', [
        (1000, "height:2.5"),       # Înălțimea peretelui
        (1000, "Name:ConcreteCore"),
        (1000, "solid:1")
    ])
    
    # Tencuială exterioară
    exterior_plaster = wall_block.add_lwpolyline([
        (-0.02, -0.02), (2.02, -0.02), (2.02, 0.32), (-0.02, 0.32)
    ], close=True)
    exterior_plaster.dxf.layer = "plaster"
    exterior_plaster.set_xdata('QCAD', [
        (1000, "height:2.5"),
        (1000, "Name:ExteriorPlaster"),
        (1000, "solid:1")
    ])
    
    # Inserează peretele
    wall1 = msp.add_blockref('Wall_200x30', (8, 0))
    wall1.dxf.layer = "IfcWall"  # IfcType
    wall1.set_xdata('QCAD', [
        (1000, "z:0.0"),
        (1000, "rotate_x:0.0"),
        (1000, "rotate_y:0.0")
    ])
    
    # Salvează documentul
    doc.saveas('ifc_composite_test.dxf')
    print("Created ifc_composite_test.dxf with:")
    print("- IfcWindow bloc with wood frame + glass panel + steel handle + rubber seal")
    print("- IfcDoor bloc with wood panel + glass window + steel handle")
    print("- IfcWall bloc with concrete core + plaster coating")
    print("- Different IfcTypes as block layers")
    print("- Material layers on individual components")
    print("- Multiple rotation scenarios")

if __name__ == "__main__":
    create_ifc_composite_test()