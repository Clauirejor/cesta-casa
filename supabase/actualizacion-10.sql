-- Cesta Casa · actualización 10: recordar el sitio (nevera, armario, cajón…) de cada artículo
-- Pégalo en Supabase → SQL Editor → New query → Run. Se puede ejecutar más de una vez.

alter table public.articulos add column if not exists lugar text default '';
