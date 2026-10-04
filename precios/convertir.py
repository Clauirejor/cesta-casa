"""Convierte precios-supermercados.xlsx en referencia.json para la app.
Uso:  python3 precios/convertir.py   (desde la carpeta del repositorio)
"""
import json, re, os, datetime
from openpyxl import load_workbook

AQUI = os.path.dirname(os.path.abspath(__file__))
XLSX = os.path.join(AQUI, 'precios-supermercados.xlsx')
SALIDA = os.path.join(AQUI, 'referencia.json')

def cantidad(fmt):
    """'250 g' -> (0.25,'kg'); '2 x 150 g' -> (0.3,'kg'); '1 l' -> (1,'l'); si no se entiende -> None"""
    s = str(fmt or '').lower().replace(',', '.')
    conv = {'kg': (1, 'kg'), 'g': (.001, 'kg'), 'gr': (.001, 'kg'), 'grs': (.001, 'kg'),
            'l': (1, 'l'), 'lt': (1, 'l'), 'litro': (1, 'l'), 'litros': (1, 'l'), 'ml': (.001, 'l'), 'cl': (.01, 'l')}
    pat = r'(kg|grs|gr|g|litros|litro|lt|ml|cl|l)\b'
    m = re.search(r'(\d+)\s*x\s*(\d+(?:\.\d+)?)\s*' + pat, s)
    if m:
        f, b = conv[m.group(3)]; return float(m.group(1)) * float(m.group(2)) * f, b
    m = re.search(r'(\d+(?:\.\d+)?)\s*' + pat, s)
    if m:
        f, b = conv[m.group(2)]; q = float(m.group(1)) * f
        return (q, b) if q > 0 else None
    return None

def campo(texto, clave):
    m = re.search(r'^' + re.escape(clave) + r'\s*:\s*(.*)$', texto or '', re.M)
    return m.group(1).strip() if m else ''

ws = load_workbook(XLSX)['Precios']
cab = [c.value for c in ws[1]]
SUPERS = [s for s in cab[4:9]]
filas, hoy = [], datetime.date.today().isoformat()
for row in ws.iter_rows(min_row=2):
    nombre = row[0].value
    if not nombre or str(nombre).upper().startswith('EJEMPLO'):
        continue
    nota_fila = str(row[10].value or '') if len(row) > 10 else ''
    for i, s in enumerate(SUPERS):
        c = row[4 + i]
        if not isinstance(c.value, (int, float)) or c.value <= 0:
            continue
        com = c.comment.text if c.comment else ''
        valor = campo(com, 'Valor de la celda')
        m = re.search(r'€\s*/\s*(ud|kg|l)\b', valor)
        unidad = m.group(1) if m else (row[2].value or 'ud')
        fmt = campo(com, 'Formato')
        if not fmt or 'ver nota' in fmt.lower():
            fmt = ''
        fecha = campo(com, 'Consultado')
        mf = re.search(r'Fecha de registro de fuente:\s*(\d{4}-\d{2}-\d{2})', com)
        fecha = mf.group(1) if mf else hoy
        fuente = 'Cestio (indirecta)' if campo(com, 'Fuente indirecta') else ('Web de ' + s if com else 'Tabla')
        r = {'nombre': nombre, 'super': s, 'precio': round(float(c.value), 2), 'unidad': unidad, 'fecha': fecha,
             'producto': campo(com, 'Producto consultado'), 'formato': fmt, 'fuente': fuente, 'url': campo(com, 'URL')}
        if 'oferta' in nota_fila.lower():
            r['nota'] = 'Puede incluir oferta'
        sin_kilo = str(row[1].value or '') in ('Hogar y bricolaje', 'Papelería y oficina', 'Ropa y calzado', 'Electrónica', 'Otros') or str(nombre).lower().startswith('bolsas')
        if sin_kilo:
            pass
        elif unidad in ('kg', 'l'):
            r['pu'], r['base'] = r['precio'], unidad
        else:
            q = cantidad(fmt)
            if q:
                r['pu'], r['base'] = round(r['precio'] / q[0], 2), q[1]
        filas.append(r)
json.dump({'actualizado': hoy, 'precios': filas}, open(SALIDA, 'w'), ensure_ascii=False, indent=0)
print(len(filas), 'precios ·', len({f["nombre"] for f in filas}), 'productos ·', sum(1 for f in filas if 'pu' in f), 'con €/kg o €/l')
