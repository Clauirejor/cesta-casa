-- Cesta Casa · actualización 8: tipos de producto propios de cada casa
-- Permite crear tipos nuevos (p. ej. «Snacks») y cambiar el nombre o el icono de los que vienen.
-- Pégalo en Supabase → SQL Editor → New query → Run. Se puede ejecutar más de una vez.

create table if not exists public.tipos (
  id uuid primary key default gen_random_uuid(),
  hogar_id uuid not null references public.hogares(id) on delete cascade,
  nombre text not null,
  emoji text default '📦',
  orden int default 50,
  oculto boolean not null default false,
  created_at timestamptz not null default now(),
  unique (hogar_id, nombre)
);

alter table public.tipos enable row level security;
drop policy if exists "hogar" on public.tipos;
create policy "hogar" on public.tipos for all to authenticated
  using (public.es_miembro(hogar_id)) with check (public.es_miembro(hogar_id));

do $$
begin
  if not exists (select 1 from pg_publication_tables where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'tipos') then
    alter publication supabase_realtime add table public.tipos;
  end if;
end $$;
