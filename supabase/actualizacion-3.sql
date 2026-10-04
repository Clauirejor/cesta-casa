-- Cesta Casa · actualización 3: tamaño del envase en los precios
-- Guarda el tamaño (400 g, 1 l, 12 ud…) para comparar siempre por kilo, litro o unidad.
-- Pégalo en Supabase → SQL Editor → New query → Run. Se puede ejecutar más de una vez.

alter table public.precios add column if not exists formato text default '';
