# Instructiuni utilizare ElementRegistry (registru de tipuri CAD/BIM)

## 1. Importă registrul în scriptul tău
```gdscript
const ElementRegistry = preload("res://element_registry.gd")
```

## 2. Înregistrează funcții de creare pentru fiecare tip de element
Poți folosi funcțiile implicite sau să adaugi altele:
```gdscript
ElementRegistry.register_defaults() # Înregistrează column, wall, shell

# Exemplu pentru un tip nou:
func create_custom(obj):
    # ...generează mesh/nod pentru tipul custom...
    return Node3D.new()
ElementRegistry.register_type("custom", Callable(self, "create_custom"))
```

## 3. Creează elemente din JSON
```gdscript
var obj = {
    "type": "column",
    "center": [1,2],
    "width": 0.3,
    "length": 0.3,
    "height": 3.0
}
var element = ElementRegistry.create_element(obj)
# element va fi structura/nodul generat de funcția de tip
```

## 4. Integrare în viewer
- La importul unui obiect din librărie, apelezi:
```gdscript
var element = ElementRegistry.create_element(json_obj)
if element:
    add_child(element) # sau procesezi mesh-ul/structura
```

## 5. Extindere
- Pentru orice tip nou, adaugi doar o funcție de creare și o înregistrezi:
```gdscript
ElementRegistry.register_type("beam", Callable(self, "create_beam"))
```

## 6. Modularitate
- Poți păstra funcțiile de creare în scripturi separate și le înregistrezi la inițializare.
- Poți folosi registrul în orice context (2D, 3D, BIM, etc).

---
**Avantaje:**
- Adaugi rapid tipuri noi fără să modifici codul principal.
- Separi logica de creare de logica de import/desen/viewer.
- Poți partaja registrul între mai multe module sau proiecte.
