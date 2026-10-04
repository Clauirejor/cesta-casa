-- Cesta Casa · actualización 5: ofertas apuntadas a mano
-- Guarda hasta cuándo vale una oferta y el precio de antes.
-- Pégalo en Supabase → SQL Editor → New query → Run. Se puede ejecutar más de una vez.

alter table public.precios add column if not exists hasta date;
alter table public.precios add column if not exists antes numeric;
