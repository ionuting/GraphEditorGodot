# DXF Watchdog System - Documentație

## Descriere
Sistem automat de monitorizare și reîncărcare a fișierelor DXF în viewer-ul CAD.

## Componente

### 1. **dxf_watchdog.py**
- Monitorizează folderul `dxf_input/` pentru modificări ale fișierelor .dxf
- La detectarea unei modificări, convertește automat DXF → GLB
- Notifică Godot prin fișierul `reload_signal.json`

### 2. **cad_viewer_3d.gd** (modificat)
- Pornește automat procesul Python watchdog
- Monitorizează fișierul `reload_signal.json` în fiecare secundă
- Reîncarcă automat geometria când detectează modificări

## Instalare

1. **Instalează dependințele Python:**
   ```cmd
   install_watchdog_deps.bat
   ```

2. **Pornește Godot viewer-ul** - watchdog-ul va porni automat

## Utilizare

1. **Pentru monitorizare automată:**
   - Pune fișierele .dxf în folderul `dxf_input/`
   - Modifică fișierele DXF în aplicația ta preferată
   - Salvează fișierul
   - Geometria se va actualiza automat în viewer în câteva secunde

2. **Pentru monitorizare manuală:**
   ```cmd
   python python/dxf_watchdog.py
   ```

## Structura folderelor
```
viewer2d/
├── dxf_input/          # Pune aici fișierele DXF
├── glb_output/         # GLB-urile generate automat
├── python/
│   ├── dxf_watchdog.py
│   └── dxf_to_glb_trimesh.py
└── reload_signal.json  # Fișier de comunicare cu Godot
```

## Avantaje

✅ **Monitorizare în timp real** - Folosește API-ul nativ de file system  
✅ **Eficient** - Procesează doar fișierele modificate  
✅ **Non-blocking** - Nu blochează Godot  
✅ **Auto-recovery** - Gestionează erorile de conversie  
✅ **Hot-reload** - Actualizare fără restart  

## Configurare avansată

În `dxf_watchdog.py` poți modifica:
- `watch_folder` - folderul monitorizat
- `output_folder` - folderul pentru GLB-uri
- Timingul pentru detectarea completă a scrierii fișierului

## Troubleshooting

**Watchdog nu pornește:**
- Verifică că Python și pip sunt instalate
- Rulează `install_watchdog_deps.bat`

**Fișierele nu se reîncarcă:**
- Verifică că folderul `dxf_input/` există
- Verifică logs în consolă pentru erori de conversie

**Performanță:**
- Pentru fișiere mari, crește timpul de delay în `_process_dxf_file()`
- Pentru multe fișiere, consideră batching