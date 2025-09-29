import ezdxf
import json
import collections


doc = ezdxf.readfile("exemplu_nou.dxf")
msp = doc.modelspace()


entities = []
for e in msp:
    ent_type = e.dxftype()
    ent = {
        "type": ent_type,
        "handle": e.dxf.handle,
        "layer": e.dxf.layer,
    }


    # XDATA (proprietăți custom, inclusiv QCAD)
    xdata = {}
    if e.has_xdata:
        # Încearcă să extragi toate appid-urile dacă metoda există
        appids = []
        if hasattr(e, "get_xdata_appids"):
            appids = e.get_xdata_appids()
        # Adaugă explicit 'QCAD' dacă nu e deja în listă
        if "QCAD" not in appids:
            appids.append("QCAD")
        for appid in appids:
            try:
                data = e.get_xdata(appid)
                if data:
                    xdata[appid] = [(code, value) for code, value in data]
            except Exception:
                pass
    if xdata:
        ent["xdata"] = xdata


    # TEXT
    if ent_type == "TEXT":
        ent["text"] = e.dxf.text
        ent["position"] = [e.dxf.insert.x, e.dxf.insert.y]
        ent["layer"] = e.dxf.layer
    # MTEXT
    elif ent_type == "MTEXT":
        ent["text"] = e.text
        ent["position"] = [e.dxf.insert.x, e.dxf.insert.y]
        ent["layer"] = e.dxf.layer
    # CIRCLE
    elif ent_type == "CIRCLE":
        ent["center"] = [e.dxf.center.x, e.dxf.center.y]
        ent["radius"] = e.dxf.radius
        ent["layer"] = e.dxf.layer
    # ARC
    elif ent_type == "ARC":
        ent["center"] = [e.dxf.center.x, e.dxf.center.y]
        ent["radius"] = e.dxf.radius
        ent["start_angle"] = e.dxf.start_angle
        ent["end_angle"] = e.dxf.end_angle
        ent["layer"] = e.dxf.layer
    # LWPOLYLINE (poligon inchis)
    elif ent_type == "LWPOLYLINE":
        points = [[p[0], p[1]] for p in e.get_points()]
        ent["points"] = points
        ent["closed"] = e.closed
        ent["layer"] = e.dxf.layer
    # POLYLINE (poligon inchis)
    elif ent_type == "POLYLINE":
        points = [[v.dxf.location.x, v.dxf.location.y] for v in e.vertices()]
        ent["points"] = points
        ent["closed"] = e.is_closed
        ent["layer"] = e.dxf.layer
    # BLOCKINSERT
    elif ent_type == "INSERT":
        ent["block_name"] = e.dxf.name
        ent["insert"] = [e.dxf.insert.x, e.dxf.insert.y]
        ent["rotation"] = e.dxf.rotation if hasattr(e.dxf, "rotation") else 0
        ent["scale"] = [e.dxf.xscale, e.dxf.yscale] if hasattr(e.dxf, "xscale") else [1, 1]
        ent["layer"] = e.dxf.layer
    entities.append(ent)


with open("C:/Users/ionut.ciuntuc/Documents/viewer2d/json_folder/out1.json", "w", encoding="utf-8") as f:
    json.dump(entities, f, indent=2, default=str)



