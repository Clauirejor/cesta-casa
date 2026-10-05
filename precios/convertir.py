"""Convierte precios-supermercados.xlsx en referencia.json para la app.

Uso (desde la carpeta del repositorio):  python3 precios/convertir.py

Cada precio se guarda también en proporción para poder comparar envases distintos:
  kg / l      -> productos a peso o volumen (€/kg, €/l)
  ud          -> productos que se venden por unidades (€/huevo, €/rollo, €/cápsula…)
  lavado      -> detergentes y suavizantes (€/lavado)
  m           -> film, papel de horno, hilo… (€/metro)
Las piezas sin peso (fruta, pescado «pieza precio aprox.») se estiman con el peso de la
pieza que publica otro súper para el mismo producto y se marcan como estimadas (est).
"""
import json, re, os, datetime, statistics
from openpyxl import load_workbook

AQUI = os.path.dirname(os.path.abspath(__file__))
XLSX = os.path.join(AQUI, 'precios-supermercados.xlsx')
SALIDA = os.path.join(AQUI, 'referencia.json')

NO_ALIMENTO = {'Hogar y bricolaje', 'Papelería y oficina', 'Ropa y calzado', 'Electrónica', 'Otros'}
SOLO_CONTAR = ('bolsas', 'bayetas', 'estropajos', 'guantes', 'fregona', 'pinzas', 'perchas', 'velas',
               'vasos', 'platos', 'cubiertos', 'tupper', 'pilas', 'pila ', 'folios', 'compresas', 'tampones',
               'pañales', 'toallitas', 'pañuelos', 'tiritas', 'gasas', 'bastoncillos', 'algodón', 'cuchillas',
               'pastillas lavavajillas', 'café en cápsulas', 'infusiones', 'té', 'papel higiénico', 'papel de cocina')
PRIORIDAD = ['kg', 'l', 'lavado', 'm', 'ud']
PALABRAS_UD = (r'ud|uds|u|unidades|unidad|unid|piezas|pzas|bolsitas|c[aá]psulas|rollos|pares|hojas|bolsas|'
               r'bayetas|estropajos|pastillas|huevos|sobres|maquinillas|unds')


def medidas(texto, categoria, nombre):
    """Devuelve {base: cantidad} con lo que se pueda leer del texto."""
    s = ' ' + str(texto or '').lower().replace(',', '.') + ' '
    n = str(nombre or '').lower()
    out = {}
    solo_contar = categoria in NO_ALIMENTO or n.startswith(SOLO_CONTAR)
    if not solo_contar:
        conv = {'kg': (1, 'kg'), 'kilo': (1, 'kg'), 'kilos': (1, 'kg'), 'g': (.001, 'kg'), 'gr': (.001, 'kg'), 'grs': (.001, 'kg'),
                'l': (1, 'l'), 'lt': (1, 'l'), 'litro': (1, 'l'), 'litros': (1, 'l'), 'ml': (.001, 'l'), 'cl': (.01, 'l')}
        u = r'(kg|kilos|kilo|grs|gr|g|litros|litro|lt|ml|cl|l)\b'
        m = re.search(r'(\d+)\s*x\s*(\d+(?:\.\d+)?)\s*' + u, s)
        if m:
            f, b = conv[m.group(3)]; out[b] = float(m.group(1)) * float(m.group(2)) * f
        else:
            m = re.search(r'(\d+(?:\.\d+)?)\s*' + u, s)
            if m and float(m.group(1)) > 0:
                f, b = conv[m.group(2)]; out[b] = float(m.group(1)) * f
    m = re.search(r'(\d+)\s*(lv|lavados?)\b', s)
    if m:
        out['lavado'] = float(m.group(1))
    m = re.search(r'(\d+(?:\.\d+)?)\s*(m|metros?)\b', s)
    if m and 'lavado' not in out and float(m.group(1)) > 0:
        out['m'] = float(m.group(1))
    cnt = None
    if re.search(r'\bdocena\b|\b1\s*dc\b', s):
        cnt = 12
    for pat in (r'(?:pack|set|juego|caja)\s*(?:de\s*)?(\d+)', r'(\d+)\s*x\s*1\s*u\b',
                *([r'(\d+)\s*x\s*\d+(?:\.\d+)?\s*(?:l|ml|cl|kg|g|gr)\b'] if solo_contar else []), r'(\d+)\s*(?:' + PALABRAS_UD + r')\b\.?'):
        if cnt:
            break
        m = re.search(pat, s)
        if m and 0 < int(m.group(1)) < 5000:
            cnt = int(m.group(1))
    if cnt:
        out['ud'] = float(cnt)
    return out


def campo(texto, clave):
    m = re.search(r'^' + re.escape(clave) + r'\s*:\s*(.*)$', texto or '', re.M)
    return m.group(1).strip() if m else ''


ws = load_workbook(XLSX)['Precios']
cab = [c.value for c in ws[1]]
SUPERS = cab[4:9]
hoy = datetime.date.today().isoformat()
filas = []
for row in ws.iter_rows(min_row=2):
    nombre = row[0].value
    if not nombre or str(nombre).upper().startswith('EJEMPLO'):
        continue
    categoria = str(row[1].value or '')
    nota_fila = str(row[10].value or '') if len(row) > 10 else ''
    for i, s in enumerate(SUPERS):
        c = row[4 + i]
        if not isinstance(c.value, (int, float)) or c.value <= 0:
            continue
        com = c.comment.text if c.comment else ''
        m = re.search(r'€\s*/\s*(ud|kg|l)\b', campo(com, 'Valor de la celda'))
        unidad = m.group(1) if m else (row[2].value or 'ud')
        fmt = campo(com, 'Formato')
        if 'ver nota' in fmt.lower():
            fmt = ''
        producto = campo(com, 'Producto consultado')
        mf = re.search(r'Fecha de registro de fuente:\s*(\d{4}-\d{2}-\d{2})', com)
        r = {'nombre': nombre, 'categoria': categoria, 'super': s, 'precio': round(float(c.value), 2), 'unidad': unidad,
             'fecha': mf.group(1) if mf else hoy, 'producto': producto, 'formato': fmt,
             'fuente': 'Cestio (indirecta)' if campo(com, 'Fuente indirecta') else ('Web de ' + s if com else 'Tabla'),
             'url': campo(com, 'URL')}
        if 'oferta' in nota_fila.lower():
            r['nota'] = 'Puede incluir oferta'
        if unidad in ('kg', 'l'):
            r['_m'] = {unidad: 1.0}
        else:
            m1, m2 = medidas(fmt, categoria, nombre), medidas(producto, categoria, nombre)
            r['_m'] = {**m2, **m1}
            if not r['_m'] and categoria in NO_ALIMENTO:
                r['_m'] = {'ud': 1.0}  # artículo suelto (una alfombra, unas botas…)
        r['_pieza'] = categoria == 'Frutas y verduras' and unidad == 'ud' and (
            'pieza' in producto.lower() or fmt.lower() in ('1 ud', '1 u'))
        filas.append(r)

# hoja «Otros súper»: una fila por precio de cualquier otra cadena o tienda
cats = {str(r[0].value): str(r[1].value or '') for r in ws.iter_rows(min_row=2) if r[0].value}
if 'Otros súper' in ws.parent.sheetnames:
    for row in ws.parent['Otros súper'].iter_rows(min_row=2, values_only=True):
        nombre, sup, precio, unidad, fmt, producto, desde, hasta, nota, url = (list(row) + [None] * 10)[:10]
        if not nombre or not sup or not isinstance(precio, (int, float)) or precio <= 0:
            continue
        categoria = cats.get(str(nombre), '')
        unidad = unidad if unidad in ('ud', 'kg', 'l') else 'ud'
        fmt, producto = str(fmt or ''), str(producto or '')
        r = {'nombre': nombre, 'categoria': categoria, 'super': str(sup), 'precio': round(float(precio), 2), 'unidad': unidad,
             'fecha': str(hasta or desde or hoy)[:10], 'producto': producto, 'formato': fmt, 'fuente': 'Folleto de ' + str(sup),
             'url': str(url or '')}
        if nota:
            r['nota'] = str(nota)
        if unidad in ('kg', 'l'):
            r['_m'] = {unidad: 1.0}
        else:
            r['_m'] = {**medidas(producto, categoria, nombre), **medidas(fmt, categoria, nombre)}
            if not r['_m'] and categoria in NO_ALIMENTO:
                r['_m'] = {'ud': 1.0}
        r['_pieza'] = False
        filas.append(r)

# base común por producto (la que más precios permiten), y estimación de piezas
por_producto = {}
for r in filas:
    por_producto.setdefault(r['nombre'], []).append(r)
estimados = 0
for nombre, rs in por_producto.items():
    cuenta = {b: sum(1 for r in rs if b in r['_m']) for b in PRIORIDAD}
    base = max(PRIORIDAD, key=lambda b: (cuenta[b], -PRIORIDAD.index(b)))
    if cuenta[base] == 0:
        base = None
    pesos = [r['_m'][base] for r in rs if base in ('kg', 'l') and base in r['_m'] and r['unidad'] == 'ud']
    for r in rs:
        q = r['_m'].get(base) if base else None
        if q is None and base in ('kg', 'l') and r['_pieza'] and pesos:
            q = statistics.median(pesos); r['est'] = True; estimados += 1
        if q:
            r['q'], r['base'], r['pu'] = round(q, 4), base, round(r['precio'] / q, 4 if base in ('ud', 'lavado', 'm') else 2)
        del r['_m'], r['_pieza']

json.dump({'actualizado': hoy, 'precios': filas}, open(SALIDA, 'w'), ensure_ascii=False, indent=0)
con = sum(1 for f in filas if 'pu' in f)
print(f"{len(filas)} precios · {len(por_producto)} productos · {con} en proporción ({estimados} estimados) · {len(filas) - con} sin tamaño")
