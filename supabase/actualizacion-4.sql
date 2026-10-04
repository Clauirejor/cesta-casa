-- Cesta Casa · actualización 4: súper y tiendas propias (mercadillo, frutería…)
-- Cada casa puede añadir sus propias tiendas; las ven todos sus miembros.
-- Pégalo en Supabase → SQL Editor → New query → Run. Se puede ejecutar más de una vez.

create table if not exists public.tiendas (
  id uuid primary key default gen_random_uuid(),
  hogar_id uuid not null references public.hogares(id) on delete cascade,
  nombre text not null,
  emoji text default '🏪',
  created_at timestamptz not null default now(),
  unique (hogar_id, nombre)
);

alter table public.tiendas enable row level security;
drop policy if exists "hogar" on public.tiendas;
create policy "hogar" on public.tiendas for all to authenticated
  using (public.es_miembro(hogar_id)) with check (public.es_miembro(hogar_id));

do $$
begin
  if not exists (select 1 from pg_publication_tables where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'tiendas') then
    alter publication supabase_realtime add table public.tiendas;
  end if;
end $$;
