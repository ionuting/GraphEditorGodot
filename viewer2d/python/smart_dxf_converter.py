#!/usr/bin/env python3
"""
Smart DXF to GLB converter cu cache inteligent și optimizări
"""

import os
import time
import hashlib
import json
from pathlib import Path
import sys

# Import scriptul existent
sys.path.append(os.path.dirname(__file__))
from dxf_to_glb_trimesh import dxf_to_gltf

class SmartDXFConverter:
    def __init__(self, cache_dir="python/cache"):
        self.cache_dir = Path(cache_dir)
        self.cache_dir.mkdir(exist_ok=True)
        self.cache_file = self.cache_dir / "conversion_cache.json"
        self.load_cache()
    
    def load_cache(self):
        """Încarcă cache-ul de conversii"""
        try:
            if self.cache_file.exists():
                with open(self.cache_file, 'r') as f:
                    self.cache = json.load(f)
            else:
                self.cache = {}
        except Exception as e:
            print(f"[CACHE] Error loading cache: {e}")
            self.cache = {}
    
    def save_cache(self):
        """Salvează cache-ul de conversii"""
        try:
            with open(self.cache_file, 'w') as f:
                json.dump(self.cache, f, indent=2)
        except Exception as e:
            print(f"[CACHE] Error saving cache: {e}")
    
    def get_file_hash(self, file_path):
        """Calculează hash-ul unui fișier pentru verificarea schimbărilor"""
        try:
            hasher = hashlib.md5()
            with open(file_path, 'rb') as f:
                for chunk in iter(lambda: f.read(4096), b""):
                    hasher.update(chunk)
            return hasher.hexdigest()
        except Exception as e:
            print(f"[HASH] Error calculating hash for {file_path}: {e}")
            return None
    
    def needs_conversion(self, dxf_path, glb_path):
        """Verifică dacă fișierul DXF trebuie reconvertit"""
        dxf_path = Path(dxf_path)
        glb_path = Path(glb_path)
        
        # Verifică dacă GLB-ul există
        if not glb_path.exists():
            print(f"[SMART] GLB not found, conversion needed: {glb_path}")
            return True
        
        # Calculează hash-ul DXF-ului curent
        current_hash = self.get_file_hash(dxf_path)
        if not current_hash:
            return True
        
        # Verifică cache-ul
        cache_key = str(dxf_path)
        if cache_key in self.cache:
            cached_data = self.cache[cache_key]
            cached_hash = cached_data.get("hash")
            cached_glb_time = cached_data.get("glb_time", 0)
            
            # Verifică dacă hash-ul s-a schimbat
            if current_hash != cached_hash:
                print(f"[SMART] DXF content changed, conversion needed")
                return True
            
            # Verifică dacă GLB-ul este mai nou decât în cache
            try:
                glb_time = glb_path.stat().st_mtime
                if glb_time > cached_glb_time:
                    print(f"[SMART] GLB is newer than cache, no conversion needed")
                    return False
            except Exception:
                return True
            
            print(f"[SMART] No changes detected, skipping conversion")
            return False
        
        # Nu există în cache, trebuie convertit
        print(f"[SMART] New file, conversion needed")
        return True
    
    def convert(self, dxf_path, glb_path, force=False):
        """Convertește DXF la GLB cu cache inteligent"""
        dxf_path = Path(dxf_path)
        glb_path = Path(glb_path)
        
        print(f"[SMART] Processing: {dxf_path} -> {glb_path}")
        
        # Verifică dacă conversia este necesară
        if not force and not self.needs_conversion(dxf_path, glb_path):
            print(f"[SMART] ✓ Skipped (no changes): {glb_path}")
            return True
        
        # Înregistrează timpul de start
        start_time = time.time()
        
        try:
            # Calculează hash-ul înainte de conversie
            file_hash = self.get_file_hash(dxf_path)
            
            # Efectuează conversia
            print(f"[SMART] Converting: {dxf_path}")
            dxf_to_gltf(str(dxf_path), str(glb_path))
            
            # Verifică că GLB-ul a fost creat
            if not glb_path.exists():
                print(f"[SMART] ✗ Conversion failed: GLB not created")
                return False
            
            # Actualizează cache-ul
            conversion_time = time.time() - start_time
            self.cache[str(dxf_path)] = {
                "hash": file_hash,
                "glb_path": str(glb_path),
                "glb_time": glb_path.stat().st_mtime,
                "conversion_time": conversion_time,
                "last_converted": time.time()
            }
            self.save_cache()
            
            print(f"[SMART] ✓ Converted in {conversion_time:.2f}s: {glb_path}")
            return True
            
        except Exception as e:
            print(f"[SMART] ✗ Conversion failed: {e}")
            return False
    
    def batch_convert(self, input_dir, output_dir=None, pattern="*.dxf"):
        """Convertește în lot toate fișierele DXF dintr-un folder"""
        input_dir = Path(input_dir)
        if output_dir:
            output_dir = Path(output_dir)
        else:
            output_dir = input_dir
        
        dxf_files = list(input_dir.glob(pattern))
        if not dxf_files:
            print(f"[SMART] No DXF files found in {input_dir}")
            return
        
        print(f"[SMART] Found {len(dxf_files)} DXF files")
        converted = 0
        skipped = 0
        
        for dxf_file in dxf_files:
            glb_file = output_dir / (dxf_file.stem + ".glb")
            
            if self.convert(dxf_file, glb_file):
                if self.needs_conversion(dxf_file, glb_file):
                    converted += 1
                else:
                    skipped += 1
        
        print(f"[SMART] Batch complete: {converted} converted, {skipped} skipped")

def main():
    if len(sys.argv) < 2:
        print("Usage:")
        print("  python smart_dxf_converter.py input.dxf [output.glb]")
        print("  python smart_dxf_converter.py --batch input_folder [output_folder]")
        print("  python smart_dxf_converter.py --force input.dxf output.glb")
        return 1
    
    converter = SmartDXFConverter()
    
    if sys.argv[1] == "--batch":
        input_folder = sys.argv[2]
        output_folder = sys.argv[3] if len(sys.argv) > 3 else input_folder
        converter.batch_convert(input_folder, output_folder)
    
    elif sys.argv[1] == "--force":
        if len(sys.argv) < 4:
            print("Error: --force requires input and output files")
            return 1
        dxf_path = sys.argv[2]
        glb_path = sys.argv[3]
        converter.convert(dxf_path, glb_path, force=True)
    
    else:
        dxf_path = sys.argv[1]
        glb_path = sys.argv[2] if len(sys.argv) > 2 else Path(dxf_path).with_suffix(".glb")
        converter.convert(dxf_path, glb_path)
    
    return 0

if __name__ == "__main__":
    sys.exit(main())