-- Cesta Casa · actualización 2: fotos de recetas y productos
-- Cada casa tiene su carpeta privada: solo sus miembros ven sus fotos.
-- Pégalo en Supabase → SQL Editor → New query → Run. Se puede ejecutar más de una vez.

-- ---------- Fotos (recetas y productos) ----------
alter table public.recetas add column if not exists imagen text default '';

create or replace function public.es_miembro_txt(h text)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.miembros where hogar_id::text = h and user_id = auth.uid());
$$;

-- Carpeta privada por casa: fotos/<id de la casa>/<foto>.jpg
insert into storage.buckets (id, name, public) values ('fotos', 'fotos', false) on conflict (id) do nothing;
drop policy if exists "fotos ver" on storage.objects;
create policy "fotos ver" on storage.objects for select to authenticated
  using (bucket_id = 'fotos' and public.es_miembro_txt((storage.foldername(name))[1]));
drop policy if exists "fotos subir" on storage.objects;
create policy "fotos subir" on storage.objects for insert to authenticated
  with check (bucket_id = 'fotos' and public.es_miembro_txt((storage.foldername(name))[1]));
drop policy if exists "fotos cambiar" on storage.objects;
create policy "fotos cambiar" on storage.objects for update to authenticated
  using (bucket_id = 'fotos' and public.es_miembro_txt((storage.foldername(name))[1]));
drop policy if exists "fotos borrar" on storage.objects;
create policy "fotos borrar" on storage.objects for delete to authenticated
  using (bucket_id = 'fotos' and public.es_miembro_txt((storage.foldername(name))[1]));
