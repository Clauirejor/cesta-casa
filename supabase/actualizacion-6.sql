-- Cesta Casa · actualización 6: descripción en los artículos
-- Pégalo en Supabase → SQL Editor → New query → Run. Se puede ejecutar más de una vez.

alter table public.articulos add column if not exists descripcion text default '';
