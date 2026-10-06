-- Cesta Casa · actualización 7: sitios de la despensa (armario, nevera, cajón…)
-- Cada casa crea sus sitios; solo los ven sus miembros.
-- Pégalo en Supabase → SQL Editor → New query → Run. Se puede ejecutar más de una vez.

create table if not exists public.lugares (
  id uuid primary key default gen_random_uuid(),
  hogar_id uuid not null references public.hogares(id) on delete cascade,
  nombre text not null,
  emoji text default '📍',
  created_at timestamptz not null default now(),
  unique (hogar_id, nombre)
);

alter table public.lugares enable row level security;
drop policy if exists "hogar" on public.lugares;
create policy "hogar" on public.lugares for all to authenticated
  using (public.es_miembro(hogar_id)) with check (public.es_miembro(hogar_id));

alter table public.despensa add column if not exists lugar text default '';

do $$
begin
  if not exists (select 1 from pg_publication_tables where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'lugares') then
    alter publication supabase_realtime add table public.lugares;
  end if;
end $$;
