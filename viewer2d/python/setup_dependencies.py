#!/usr/bin/env python3
"""
Setup script pentru dependențele DXF to GLB converter
"""

import subprocess
import sys
import os

def install_package(package):
    """Instalează un pachet Python prin pip"""
    try:
        subprocess.check_call([sys.executable, "-m", "pip", "install", package])
        print(f"✓ {package} installed successfully")
        return True
    except subprocess.CalledProcessError as e:
        print(f"✗ Failed to install {package}: {e}")
        return False

def check_package(package):
    """Verifică dacă un pachet este deja instalat"""
    try:
        __import__(package)
        print(f"✓ {package} already installed")
        return True
    except ImportError:
        print(f"⚠ {package} not found, installing...")
        return False

def main():
    print("=== DXF to GLB Converter Setup ===\n")
    
    # Lista dependențelor necesare
    dependencies = [
        ("ezdxf", "ezdxf"),
        ("trimesh", "trimesh[easy]"),  # Include dependențele opționale
        ("shapely", "shapely"),
        ("watchdog", "watchdog"),
        ("numpy", "numpy")
    ]
    
    # Verifică și instalează dependențele
    all_installed = True
    for import_name, pip_name in dependencies:
        if not check_package(import_name):
            if not install_package(pip_name):
                all_installed = False
    
    print("\n=== Setup Complete ===")
    if all_installed:
        print("✓ All dependencies installed successfully!")
        print("\nYou can now use the DXF to GLB converter:")
        print("1. Run the watchdog: python python/dxf_watchdog.py")
        print("2. Or convert manually: python python/dxf_to_glb_trimesh.py input.dxf output.glb")
    else:
        print("✗ Some dependencies failed to install. Please install them manually.")
        return 1
    
    return 0

if __name__ == "__main__":
    sys.exit(main())