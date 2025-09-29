import ezdxf
from ezdxf.math import Vec2, ConstructionLine
import math
from typing import List, Tuple, Optional
from shapely.geometry import LineString, Polygon, Point
from shapely.ops import unary_union, polygonize
import numpy as np

class DXFCellOffsetProcessor:
    def __init__(self, dxf_file_path: str, offset_distance: float = 0.25):
        """
        Initializează procesorul pentru crearea de poligoane offset în celule.
        
        Args:
            dxf_file_path: Calea către fișierul DXF
            offset_distance: Distanța de offset (ex: 0.25)
        """
        self.dxf_file_path = dxf_file_path
        self.offset_distance = offset_distance
        self.doc = None
        self.lines = []
        
    def load_dxf(self):
        """Încarcă fișierul DXF și extrage liniile."""
        try:
            self.doc = ezdxf.readfile(self.dxf_file_path)
            msp = self.doc.modelspace()
            
            # Extrage toate liniile
            self.lines = []
            for entity in msp:
                if entity.dxftype() == 'LINE':
                    start = Vec2(entity.dxf.start.x, entity.dxf.start.y)
                    end = Vec2(entity.dxf.end.x, entity.dxf.end.y)
                    self.lines.append((start, end))
                elif entity.dxftype() == 'LWPOLYLINE':
                    # Convertește polyline în segmente de linie
                    points = list(entity.get_points())
                    for i in range(len(points) - 1):
                        start = Vec2(points[i][0], points[i][1])
                        end = Vec2(points[i+1][0], points[i+1][1])
                        self.lines.append((start, end))
                        
            print(f"S-au încărcat {len(self.lines)} linii din DXF")
            return True
            
        except Exception as e:
            print(f"Eroare la încărcarea DXF: {e}")
            return False
    
    def find_closed_cells(self) -> List[List[Vec2]]:
        """
        Găsește celulele închise (poligoane) formate din intersecția liniilor.
        Folosește Shapely pentru detectarea poligoanelor.
        """
        try:
            # Convertește liniile în format Shapely
            shapely_lines = []
            for start, end in self.lines:
                line = LineString([(start.x, start.y), (end.x, end.y)])
                shapely_lines.append(line)
            
            # Creează uniunea tuturor liniilor
            line_union = unary_union(shapely_lines)
            
            # Găsește poligoanele închise
            polygons = list(polygonize(line_union))
            
            # Convertește înapoi în format Vec2
            cells = []
            for poly in polygons:
                if poly.is_valid and poly.area > 1e-6:  # Ignoră poligoanele foarte mici
                    coords = list(poly.exterior.coords[:-1])  # Exclude ultimul punct duplicat
                    cell_points = [Vec2(x, y) for x, y in coords]
                    cells.append(cell_points)
            
            print(f"S-au găsit {len(cells)} celule închise")
            return cells
            
        except Exception as e:
            print(f"Eroare la găsirea celulelor: {e}")
            return []
    
    def calculate_symmetric_offset(self, cell_points: List[Vec2]) -> List[Vec2]:
        """
        Calculează offset-ul simetric pentru o celulă.
        
        Args:
            cell_points: Lista de puncte ale celulei
            
        Returns:
            Lista de puncte ale poligonului offset
        """
        try:
            # Convertește în Shapely Polygon
            coords = [(p.x, p.y) for p in cell_points]
            polygon = Polygon(coords)
            
            # Calculează offset-ul interior (negativ pentru interior)
            offset_poly = polygon.buffer(-self.offset_distance, 
                                       join_style=2,  # Miter join
                                       mitre_limit=2.0)
            
            if offset_poly.is_empty or offset_poly.area < 1e-6:
                return []
            
            # Extrage coordonatele exterior
            if hasattr(offset_poly, 'exterior'):
                coords = list(offset_poly.exterior.coords[:-1])
            else:
                # În cazul unui MultiPolygon, ia primul poligon
                if hasattr(offset_poly, 'geoms'):
                    coords = list(offset_poly.geoms[0].exterior.coords[:-1])
                else:
                    return []
            
            # Convertește înapoi în Vec2
            offset_points = [Vec2(x, y) for x, y in coords]
            return offset_points
            
        except Exception as e:
            print(f"Eroare la calcularea offset-ului: {e}")
            return []
    
    def create_offset_polygons_dxf(self, output_path: str):
        """
        Creează fișierul DXF cu poligoanele offset.
        
        Args:
            output_path: Calea către fișierul de ieșire
        """
        try:
            # Creează un document DXF nou
            new_doc = ezdxf.new('R2010')
            msp = new_doc.modelspace()
            
            # Adaugă liniile originale (opțional, pentru referință)
            for start, end in self.lines:
                msp.add_line(
                    start=(start.x, start.y, 0),
                    end=(end.x, end.y, 0),
                    dxfattribs={'color': 8}  # Gri
                )
            
            # Găsește celulele închise
            cells = self.find_closed_cells()
            
            # Procesează fiecare celulă
            created_polygons = 0
            for i, cell in enumerate(cells):
                offset_points = self.calculate_symmetric_offset(cell)
                
                if len(offset_points) >= 3:
                    # Creează poligonul offset ca LWPOLYLINE
                    points_2d = [(p.x, p.y) for p in offset_points]
                    
                    # Adaugă poligonul
                    lwpoly = msp.add_lwpolyline(
                        points_2d,
                        close=True,
                        dxfattribs={'color': 2}  # Galben
                    )
                    created_polygons += 1
            
            # Salvează fișierul
            new_doc.saveas(output_path)
            print(f"S-au creat {created_polygons} poligoane offset")
            print(f"Fișierul salvat ca: {output_path}")
            return True
            
        except Exception as e:
            print(f"Eroare la crearea DXF-ului: {e}")
            return False
    
    def process(self, output_path: str):
        """
        Procesează complet fișierul DXF.
        
        Args:
            output_path: Calea către fișierul de ieșire
        """
        print(f"Procesarea fișierului: {self.dxf_file_path}")
        print(f"Offset distance: {self.offset_distance}")
        
        if not self.load_dxf():
            return False
            
        return self.create_offset_polygons_dxf(output_path)

# Exemplu de utilizare
def main():
    """Exemplu de utilizare a algoritmului."""
    
    # Configurare
    input_file = "C:/jupyter/intersecting_lines.dxf"  # Calea către fișierul DXF de intrare
    output_file = "C:/jupyter/output_with_offset_polygons.dxf"  # Calea către fișierul de ieșire
    offset_value = 0.25  # Valoarea offset-ului
    
    # Creează procesorul
    processor = DXFCellOffsetProcessor(input_file, offset_value)
    
    # Procesează fișierul
    success = processor.process(output_file)
    
    if success:
        print("Procesarea s-a finalizat cu succes!")
    else:
        print("A apărut o eroare în timpul procesării.")

# Funcție auxiliară pentru testare cu date sintetice
def create_test_dxf(filename: str):
    """Creează un fișier DXF de test cu o grilă simplă."""
    doc = ezdxf.new('R2010')
    msp = doc.modelspace()
    
    # Creează o grilă 3x3
    for i in range(4):
        # Linii verticale
        msp.add_line(start=(i, 0, 0), end=(i, 3, 0))
        # Linii orizontale  
        msp.add_line(start=(0, i, 0), end=(3, i, 0))
    
    doc.saveas(filename)
    print(f"Fișier de test creat: {filename}")

if __name__ == "__main__":
    # Uncomment pentru a crea un fișier de test
    # create_test_dxf("test_grid.dxf")
    
    main()