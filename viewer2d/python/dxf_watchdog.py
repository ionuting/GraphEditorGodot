import os
import time
import json
import subprocess
from pathlib import Path
from watchdog.observers import Observer
from watchdog.events import FileSystemEventHandler

class DXFHandler(FileSystemEventHandler):
    def __init__(self, watch_folder, output_folder, conversion_script, callback_file):
        self.watch_folder = Path(watch_folder)
        self.output_folder = Path(output_folder)
        self.conversion_script = Path(conversion_script)
        self.callback_file = Path(callback_file)
        self.processing = set()  # Pentru a evita procesarea multiplă
        
    def on_modified(self, event):
        if event.is_directory:
            return
            
        file_path = Path(event.src_path)
        if file_path.suffix.lower() == '.dxf':
            self._process_dxf_file(file_path)
    
    def on_created(self, event):
        if event.is_directory:
            return
            
        file_path = Path(event.src_path)
        if file_path.suffix.lower() == '.dxf':
            # Așteaptă ca fișierul să fie complet scris
            time.sleep(0.5)
            self._process_dxf_file(file_path)
    
    def _process_dxf_file(self, dxf_path):
        if str(dxf_path) in self.processing:
            return
            
        self.processing.add(str(dxf_path))
        
        try:
            print(f"[WATCHDOG] DXF file changed: {dxf_path}")
            
            # Calculează calea de output
            glb_path = self.output_folder / (dxf_path.stem + ".glb")
            
            # Rulează conversia DXF → GLB
            print(f"[WATCHDOG] Converting {dxf_path} → {glb_path}")
            result = subprocess.run([
                "python", 
                str(self.conversion_script),
                str(dxf_path),
                str(glb_path)
            ], capture_output=True, text=True)
            
            if result.returncode == 0:
                print(f"[WATCHDOG] Conversion successful")
                
                # Notifică Godot despre schimbare
                self._notify_godot_reload(dxf_path, glb_path)
            else:
                print(f"[WATCHDOG] Conversion failed: {result.stderr}")
                
        except Exception as e:
            print(f"[WATCHDOG] Error processing {dxf_path}: {e}")
        finally:
            self.processing.discard(str(dxf_path))
    
    def _notify_godot_reload(self, dxf_path, glb_path):
        """Scrie un signal file pentru Godot să știe că trebuie să reîncarce"""
        signal_data = {
            "timestamp": time.time(),
            "dxf_file": str(dxf_path),
            "glb_file": str(glb_path),
            "action": "reload"
        }
        
        try:
            with open(self.callback_file, 'w') as f:
                json.dump(signal_data, f, indent=2)
            print(f"[WATCHDOG] Godot notified via {self.callback_file}")
        except Exception as e:
            print(f"[WATCHDOG] Failed to notify Godot: {e}")

def main():
    # Configurație
    watch_folder = r"C:\Users\ionut.ciuntuc\Documents\viewer2d\dxf_input"
    output_folder = r"C:\Users\ionut.ciuntuc\Documents\viewer2d\glb_output" 
    conversion_script = r"C:\Users\ionut.ciuntuc\Documents\viewer2d\python\dxf_to_glb_trimesh.py"
    callback_file = r"C:\Users\ionut.ciuntuc\Documents\viewer2d\reload_signal.json"
    
    # Crează folderele dacă nu există
    Path(watch_folder).mkdir(exist_ok=True)
    Path(output_folder).mkdir(exist_ok=True)
    
    # Configurează watchdog
    event_handler = DXFHandler(watch_folder, output_folder, conversion_script, callback_file)
    observer = Observer()
    observer.schedule(event_handler, watch_folder, recursive=True)
    
    print(f"[WATCHDOG] Starting monitoring of {watch_folder}")
    print(f"[WATCHDOG] Output folder: {output_folder}")
    print(f"[WATCHDOG] Press Ctrl+C to stop")
    
    observer.start()
    
    try:
        while True:
            time.sleep(1)
    except KeyboardInterrupt:
        observer.stop()
        print("[WATCHDOG] Stopped")
    
    observer.join()

if __name__ == "__main__":
    main()