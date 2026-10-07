-- Cesta Casa · actualización 11: avisos push en el móvil (aunque la app esté cerrada)
-- Pégalo en Supabase → SQL Editor → New query → Run. Se puede ejecutar más de una vez.
-- Guarda a qué móviles hay que avisar. Cada persona solo ve y cambia los suyos.

create table if not exists public.push_subs (
  id uuid primary key default gen_random_uuid(),
  hogar_id uuid not null references public.hogares(id) on delete cascade,
  user_id uuid not null default auth.uid(),
  endpoint text not null unique,
  p256dh text not null,
  auth text not null,
  created_at timestamptz not null default now()
);
alter table public.push_subs enable row level security;
drop policy if exists "mis avisos" on public.push_subs;
create policy "mis avisos" on public.push_subs for all to authenticated
  using (user_id = auth.uid())
  with check (user_id = auth.uid() and public.es_miembro(hogar_id));
