# Cesta Casa

Lista de la compra compartida, despensa, plan semanal y precios para casa. Es una PWA de un solo archivo (`index.html`) que guarda los datos en Supabase. No usa ningún servicio de pago.

![Vista previa](vista-previa.png)

## Archivos

| Archivo | Para qué sirve |
|---|---|
| `index.html` | La app entera |
| `manifest.webmanifest`, `sw.js`, `icon-*.png` | Para instalarla en el móvil como una app |
| `supabase/schema.sql` | Tablas, seguridad, tiempo real, 410 artículos ya cargados y 15 recetas de inicio |

---

## Puesta en marcha de Supabase

### 1. Crear el proyecto (3 min)
1. Entra en https://supabase.com → **New project**.
2. Nombre: `cesta-casa`. Pon una contraseña de base de datos (guárdala, aunque la app no la usa). Región: **West EU (Ireland)** o **Central EU (Frankfurt)**.
3. Espera a que termine de crearse (1-2 minutos).

### 2. Crear las tablas (1 min)
1. Menú izquierdo → **SQL Editor** → **New query**.
2. Abre [`supabase/schema.sql`](supabase/schema.sql), pulsa el botón de copiar (o **Raw** → seleccionar todo), pégalo y pulsa **Run**.
3. Debe salir **Success. No rows returned**. Si lo ejecutas otra vez no pasa nada.

### 3. Quitar la confirmación por correo (1 min)
1. **Authentication** → **Sign In / Providers** → **Email**.
2. Desactiva **Confirm email** → **Save**.

(Si lo dejas activado también funciona, pero cada uno tendrá que pulsar el enlace del correo antes de entrar.)

### 4. Copiar la URL y la clave (1 min)
1. **Project Settings** (rueda abajo a la izquierda) → **API Keys** (o **Data API**).
2. Copia la **Project URL** (`https://xxxx.supabase.co`) y la clave **anon public** (o **publishable**, empieza por `sb_publishable_`).
3. Nunca copies la clave **service_role / secret**.

### 5. Abrir la app y crear el hogar
1. Abre la app en el móvil. La primera vez te pide la URL y la clave del paso 4: pégalas y pulsa **Conectar**.
2. **Crear cuenta nueva** con tu correo y una contraseña → escribe tu nombre → **Crear hogar**.
3. En la pestaña **Más** aparece el **código para unirse** (6 letras).
4. Tu mujer abre la app en su móvil, pega la misma URL y clave, crea su cuenta, escribe su nombre y el código → **Unirme**.

### 6. Cerrar la puerta (1 min)
Cuando estéis los dos dentro: **Authentication** → **Sign In / Providers** → desactiva **Allow new users to sign up** → **Save**. Así nadie más puede crear cuentas.

> La clave anon es pública por diseño. La seguridad la ponen las reglas del `schema.sql`: cada hogar solo ve sus datos.

### Opcional: no tener que pegar la clave en cada móvil
Edita `index.html` y, al principio del script, rellena:
```js
const CONFIG = { supabaseUrl: "https://xxxx.supabase.co", supabaseAnonKey: "tu-clave-anon" };
```

---

## Instalar en el móvil
- **iPhone (Safari):** Compartir → **Añadir a pantalla de inicio**.
- **Android (Chrome):** menú ⋮ → **Instalar aplicación**.

## Importar un ticket

1. En **Precios** (o en el menú ··· de la lista) pulsa **Importar ticket** → **Copiar instrucciones para la IA**.
2. Pega las instrucciones en la IA que uses (ChatGPT, Claude, Gemini…) junto con la foto del ticket.
3. Copia lo que te responda, pégalo en la app y pulsa **Revisar** → **Guardar ticket**.

Al guardar, se apuntan los precios, se tacha de la lista lo comprado y la comida, la limpieza y la higiene pasan a la despensa.

### Formato

```
SUPER: Mercadona
FECHA: 2026-10-04
Tomate frito; Hacendado; 2; ud; 1,90
Plátano; ; 1,2; kg; 2,34
Folios; ; 1; ud; 4,50
```

- Una línea por producto: **Producto; Marca; Cantidad; Unidad; Importe**.
- Unidad: `ud`, `kg` o `l`. El importe es lo pagado por esa línea; vale coma o punto.
- `SUPER:` y `FECHA:` son opcionales (la fecha también vale como `04/10/2026`).
- Versiones cortas que también entiende:
  - `Producto; Importe`
  - `Producto; Cantidad; Importe`
  - `Producto; Marca; Cantidad; Importe`
- También acepta columnas separadas por tabulador (copiadas de Excel o Google Sheets), líneas con viñetas (`- `) y JSON.

## Cómo se usa
- **Compra:** escribe ("2 leche", "folios", "zapatos") o toca un **Habitual**. Todo lo que apuntáis una vez queda en **Mis artículos** para volver a ponerlo con un toque. Lo de casa (papelería, ropa, bricolaje…) sale en su propio grupo.
- Al marcar algo como comprado, al otro le aparece al momento ("Jorge ha marcado Tomate frito · Hacendado · Mercadona").
- **Guardar compra:** la comida, la limpieza y la higiene pasan a la **Despensa**. Los folios o los zapatos quedan apuntados como comprados.
- **Despensa:** botones **Gastado**, **Usar 1** y **Tirado**. Si algo se acaba, la app te ofrece volver a ponerlo en la lista.
- **Precios:** histórico por súper, estrellas de calidad y la etiqueta **Compensa** (mejor calidad por euro).
- **Escanear código de barras:** busca el producto en Open Food Facts (gratis) y lo recuerda la próxima vez.
- **Plan semanal:** eliges recetas para el desayuno, la comida y la cena, y **Generar lista de la compra** añade lo que falta sin repetir lo que ya hay en la despensa.

## Límites
- Los avisos llegan con la app abierta o usada hace poco. Si está cerrada del todo, los veréis al abrirla.
- El escáner necesita permiso de cámara.
