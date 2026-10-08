-- Cesta Casa · actualización 12: bodega (vinos, cavas, champagne y espumosos)
-- Pégalo en Supabase → SQL Editor → New query → Run. Se puede ejecutar más de una vez.

create table if not exists public.vinos (
  id uuid primary key default gen_random_uuid(),
  hogar_id uuid not null references public.hogares(id) on delete cascade,
  nombre text not null,
  tipo text default 'Tinto',
  bodega text default '',
  region text default '',
  uva text default '',
  anada int,
  precio numeric default 0,
  super text default '',
  valoracion int default 0,
  notas text default '',
  imagen text default '',
  ean text default '',
  botellas numeric default 0,
  por uuid,
  created_at timestamptz not null default now()
);
alter table public.vinos enable row level security;
drop policy if exists "hogar" on public.vinos;
create policy "hogar" on public.vinos for all to authenticated
  using (public.es_miembro(hogar_id)) with check (public.es_miembro(hogar_id));
do $$ begin
  if not exists (select 1 from pg_publication_tables where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'vinos') then
    alter publication supabase_realtime add table public.vinos;
  end if;
end $$;
