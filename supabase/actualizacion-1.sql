-- Cesta Casa · actualización 1: varias casas por persona y borrar casa
-- - Estar en varias casas a la vez (la tuya, la de tus padres, la de un viaje…)
-- - Salir de una casa
-- - Borrar una casa para todos (solo quien la creó)
-- Pégalo en Supabase → SQL Editor → New query → Run. Se puede ejecutar más de una vez.

alter table public.hogares add column if not exists creado_por uuid;

create or replace function public.crear_hogar(p_nombre text, p_mi_nombre text, p_color text default '#3478F6')
returns public.hogares language plpgsql security definer set search_path = public as $$
declare h public.hogares; c text;
begin
  if auth.uid() is null then raise exception 'Sin sesión'; end if;
  loop
    c := upper(substr(md5(random()::text || clock_timestamp()::text), 1, 6));
    exit when not exists (select 1 from public.hogares where codigo = c);
  end loop;
  insert into public.hogares (nombre, codigo, creado_por) values (coalesce(nullif(p_nombre,''),'Casa'), c, auth.uid()) returning * into h;
  insert into public.miembros (hogar_id, user_id, nombre, color) values (h.id, auth.uid(), p_mi_nombre, p_color);
  insert into public.recetas (hogar_id, nombre, emoji, minutos, momento, ingredientes)
    select h.id, nombre, emoji, minutos, momento, ingredientes from public.recetas_base;
  return h;
end $$;

create or replace function public.unirse_hogar(p_codigo text, p_mi_nombre text, p_color text default '#FF2D55')
returns public.hogares language plpgsql security definer set search_path = public as $$
declare h public.hogares;
begin
  if auth.uid() is null then raise exception 'Sin sesión'; end if;
  select * into h from public.hogares where codigo = upper(trim(p_codigo));
  if h.id is null then raise exception 'Código no válido'; end if;
  insert into public.miembros (hogar_id, user_id, nombre, color) values (h.id, auth.uid(), p_mi_nombre, p_color)
    on conflict (hogar_id, user_id) do update set nombre = excluded.nombre;
  return h;
end $$;

-- Salir de una casa. Si se queda sin nadie, se borra con sus datos.
create or replace function public.salir_hogar(p_hogar uuid)
returns void language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'Sin sesión'; end if;
  delete from public.miembros where hogar_id = p_hogar and user_id = auth.uid();
  delete from public.hogares h where h.id = p_hogar and not exists (select 1 from public.miembros m where m.hogar_id = h.id);
end $$;

-- Borrar una casa para todos. Solo quien la creó, y escribiendo su nombre exacto.
create or replace function public.borrar_hogar(p_hogar uuid, p_nombre text)
returns void language plpgsql security definer set search_path = public as $$
declare h public.hogares;
begin
  if auth.uid() is null then raise exception 'Sin sesión'; end if;
  select * into h from public.hogares where id = p_hogar;
  if h.id is null or not public.es_miembro(p_hogar) then raise exception 'Casa no encontrada'; end if;
  if h.creado_por is distinct from auth.uid() then raise exception 'Solo quien creó la casa puede borrarla'; end if;
  if trim(coalesce(p_nombre,'')) <> trim(h.nombre) then raise exception 'El nombre no coincide'; end if;
  delete from public.hogares where id = p_hogar;
end $$;

grant execute on function public.crear_hogar(text, text, text) to authenticated;
grant execute on function public.unirse_hogar(text, text, text) to authenticated;
grant execute on function public.salir_hogar(uuid) to authenticated;
grant execute on function public.borrar_hogar(uuid, text) to authenticated;
-- casas ya creadas: su creador es el primer miembro
update public.hogares h set creado_por = (select m.user_id from public.miembros m where m.hogar_id = h.id order by m.created_at limit 1) where creado_por is null;

