-- Cesta Casa · actualización 9: productos de una persona concreta (para quién es cada artículo)
-- Pégalo en Supabase → SQL Editor → New query → Run. Se puede ejecutar más de una vez.

alter table public.articulos add column if not exists para text default '';
