-- =====================================================================
--  CESTA CASA · Esquema de Supabase
--  Pégalo entero en Supabase → SQL Editor → New query → Run.
--  Se puede ejecutar más de una vez sin romper nada.
-- =====================================================================

-- ---------- Hogares y miembros ----------
create table if not exists public.hogares (
  id uuid primary key default gen_random_uuid(),
  nombre text not null default 'Casa',
  codigo text not null unique,
  creado_por uuid,
  created_at timestamptz not null default now()
);
alter table public.hogares add column if not exists creado_por uuid;

create table if not exists public.miembros (
  id uuid primary key default gen_random_uuid(),
  hogar_id uuid not null references public.hogares(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  nombre text not null,
  color text not null default '#3478F6',
  created_at timestamptz not null default now(),
  unique (hogar_id, user_id)
);

-- ¿El usuario actual es miembro de este hogar?
create or replace function public.es_miembro(h uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.miembros where hogar_id = h and user_id = auth.uid());
$$;

-- ---------- Catálogo base (común) ----------
create table if not exists public.categorias (
  nombre text primary key,
  emoji text not null,
  color text not null,
  va_a_despensa boolean not null default true,
  orden int not null default 0
);

create table if not exists public.catalogo_base (
  id serial primary key,
  nombre text not null unique,
  categoria text not null references public.categorias(nombre) on update cascade,
  emoji text not null default '📦',
  unidad text not null default 'ud'
);

create table if not exists public.recetas_base (
  id serial primary key,
  nombre text not null unique,
  emoji text not null default '🍽️',
  minutos int,
  momento text,
  ingredientes jsonb not null default '[]'::jsonb
);

-- ---------- Datos de cada hogar ----------
-- "Mis artículos": todo lo que habéis apuntado alguna vez (para Habituales)
create table if not exists public.articulos (
  id uuid primary key default gen_random_uuid(),
  hogar_id uuid not null references public.hogares(id) on delete cascade,
  nombre text not null,
  categoria text not null default 'Otros',
  emoji text not null default '📦',
  unidad text not null default 'ud',
  marca text default '',
  ean text default '',
  imagen text default '',
  descripcion text default '',
  veces int not null default 0,
  ultima timestamptz,
  oculto boolean not null default false,
  favorito boolean not null default false,
  created_at timestamptz not null default now(),
  unique (hogar_id, nombre)
);

create table if not exists public.lista (
  id uuid primary key default gen_random_uuid(),
  hogar_id uuid not null references public.hogares(id) on delete cascade,
  nombre text not null,
  emoji text default '📦',
  categoria text default 'Otros',
  cantidad numeric not null default 1,
  unidad text not null default 'ud',
  receta text default '',
  super text default '',
  marca text default '',
  precio numeric default 0,
  nota text default '',
  por uuid,
  comprado boolean not null default false,
  comprado_por uuid,
  comprado_at timestamptz,
  created_at timestamptz not null default now()
);

create table if not exists public.despensa (
  id uuid primary key default gen_random_uuid(),
  hogar_id uuid not null references public.hogares(id) on delete cascade,
  nombre text not null,
  emoji text default '📦',
  categoria text default 'Otros',
  cantidad numeric not null default 1,
  unidad text not null default 'ud',
  caduca date,
  super text default '',
  marca text default '',
  precio numeric default 0,
  por uuid,
  created_at timestamptz not null default now()
);

create table if not exists public.precios (
  id uuid primary key default gen_random_uuid(),
  hogar_id uuid not null references public.hogares(id) on delete cascade,
  nombre text not null,
  super text not null,
  marca text default '',
  precio numeric not null,
  unidad text default 'ud',
  formato text default '',
  hasta date,
  antes numeric,
  fecha date not null default current_date,
  por uuid,
  created_at timestamptz not null default now()
);
alter table public.articulos add column if not exists descripcion text default '';
alter table public.precios add column if not exists formato text default '';
alter table public.precios add column if not exists hasta date;
alter table public.precios add column if not exists antes numeric;
create index if not exists precios_hogar_nombre on public.precios (hogar_id, nombre);

create table if not exists public.valoraciones (
  id uuid primary key default gen_random_uuid(),
  hogar_id uuid not null references public.hogares(id) on delete cascade,
  nombre text not null,
  super text not null,
  marca text not null default '',
  calidad int not null default 3 check (calidad between 1 and 5),
  created_at timestamptz not null default now(),
  unique (hogar_id, nombre, super, marca)
);
alter table public.valoraciones add column if not exists created_at timestamptz not null default now();

create table if not exists public.recetas (
  id uuid primary key default gen_random_uuid(),
  hogar_id uuid not null references public.hogares(id) on delete cascade,
  nombre text not null,
  emoji text default '🍽️',
  minutos int,
  momento text,
  ingredientes jsonb not null default '[]'::jsonb,
  pasos text default '',
  created_at timestamptz not null default now()
);

create table if not exists public.menu (
  id uuid primary key default gen_random_uuid(),
  hogar_id uuid not null references public.hogares(id) on delete cascade,
  fecha date not null,
  momento text not null check (momento in ('desayuno','comida','cena')),
  receta_id uuid references public.recetas(id) on delete cascade,
  created_at timestamptz not null default now(),
  unique (hogar_id, fecha, momento)
);

create table if not exists public.eventos (
  id uuid primary key default gen_random_uuid(),
  hogar_id uuid not null references public.hogares(id) on delete cascade,
  tipo text not null,            -- comprado | consumido | tirado
  nombre text not null,
  emoji text default '',
  super text default '',
  marca text default '',
  precio numeric default 0,
  cantidad numeric default 1,
  unidad text default 'ud',
  por uuid,
  created_at timestamptz not null default now()
);
create index if not exists eventos_hogar_fecha on public.eventos (hogar_id, created_at desc);

-- Súper y tiendas propias de cada casa (mercadillo, frutería…)
create table if not exists public.tiendas (
  id uuid primary key default gen_random_uuid(),
  hogar_id uuid not null references public.hogares(id) on delete cascade,
  nombre text not null,
  emoji text default '🏪',
  created_at timestamptz not null default now(),
  unique (hogar_id, nombre)
);

-- ---------- Seguridad (RLS): cada hogar solo ve lo suyo ----------
alter table public.hogares       enable row level security;
alter table public.miembros      enable row level security;
alter table public.categorias    enable row level security;
alter table public.catalogo_base enable row level security;
alter table public.recetas_base  enable row level security;

drop policy if exists "ver mi hogar" on public.hogares;
create policy "ver mi hogar" on public.hogares for select to authenticated using (public.es_miembro(id));
drop policy if exists "editar mi hogar" on public.hogares;
create policy "editar mi hogar" on public.hogares for update to authenticated using (public.es_miembro(id));

drop policy if exists "ver miembros" on public.miembros;
create policy "ver miembros" on public.miembros for select to authenticated using (public.es_miembro(hogar_id));
drop policy if exists "editarme" on public.miembros;
create policy "editarme" on public.miembros for update to authenticated using (user_id = auth.uid());

drop policy if exists "leer categorias" on public.categorias;
create policy "leer categorias" on public.categorias for select to authenticated using (true);
drop policy if exists "leer catalogo" on public.catalogo_base;
create policy "leer catalogo" on public.catalogo_base for select to authenticated using (true);
drop policy if exists "leer recetas base" on public.recetas_base;
create policy "leer recetas base" on public.recetas_base for select to authenticated using (true);

do $$
declare t text;
begin
  foreach t in array array['articulos','lista','despensa','precios','valoraciones','recetas','menu','eventos','tiendas'] loop
    execute format('alter table public.%I enable row level security', t);
    execute format('drop policy if exists "hogar" on public.%I', t);
    execute format('create policy "hogar" on public.%I for all to authenticated using (public.es_miembro(hogar_id)) with check (public.es_miembro(hogar_id))', t);
  end loop;
end $$;

-- ---------- Crear hogar / unirse con código ----------
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

-- ---------- Tiempo real ----------
do $$
declare t text;
begin
  foreach t in array array['lista','despensa','precios','valoraciones','recetas','menu','eventos','articulos','miembros','tiendas'] loop
    if not exists (select 1 from pg_publication_tables where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = t) then
      execute format('alter publication supabase_realtime add table public.%I', t);
    end if;
  end loop;
end $$;

-- Catálogo base: artículos ya cargados para todos los hogares
insert into public.categorias (nombre, emoji, color, va_a_despensa, orden) values
  ('Frutas y verduras', '🥬', '#34C759', true, 0),
  ('Carnes y pescados', '🥩', '#FF3B30', true, 1),
  ('Charcutería y quesos', '🧀', '#FF9500', true, 2),
  ('Lácteos y huevos', '🥛', '#007AFF', true, 3),
  ('Panadería', '🥖', '#A2845E', true, 4),
  ('Pasta, arroz y legumbres', '🍝', '#FFB800', true, 5),
  ('Aceites, salsas y especias', '🫒', '#8E8E3A', true, 6),
  ('Conservas', '🥫', '#E8590C', true, 7),
  ('Desayuno y dulces', '🍪', '#C2410C', true, 8),
  ('Congelados', '🧊', '#5AC8FA', true, 9),
  ('Bebidas', '🧃', '#30B0C7', true, 10),
  ('Limpieza', '🧽', '#00A39A', true, 11),
  ('Higiene y cuidado', '🧴', '#AF52DE', true, 12),
  ('Bebé', '🍼', '#FF6FA8', true, 13),
  ('Mascotas', '🐾', '#8E6E53', true, 14),
  ('Farmacia', '💊', '#E5484D', true, 15),
  ('Hogar y bricolaje', '🔧', '#5856D6', false, 16),
  ('Papelería y oficina', '📎', '#3478F6', false, 17),
  ('Ropa y calzado', '👟', '#6E56CF', false, 18),
  ('Electrónica', '🔌', '#636366', false, 19),
  ('Otros', '📦', '#8E8E93', false, 20)
on conflict (nombre) do nothing;

insert into public.catalogo_base (nombre, categoria, emoji, unidad) values
  ('Tomate', 'Frutas y verduras', '🍅', 'kg'),
  ('Tomate cherry', 'Frutas y verduras', '🍅', 'ud'),
  ('Lechuga', 'Frutas y verduras', '🥬', 'ud'),
  ('Cebolla', 'Frutas y verduras', '🧅', 'ud'),
  ('Cebolla morada', 'Frutas y verduras', '🧅', 'ud'),
  ('Ajo', 'Frutas y verduras', '🧄', 'ud'),
  ('Patata', 'Frutas y verduras', '🥔', 'kg'),
  ('Boniato', 'Frutas y verduras', '🍠', 'kg'),
  ('Zanahoria', 'Frutas y verduras', '🥕', 'kg'),
  ('Pimiento rojo', 'Frutas y verduras', '🫑', 'ud'),
  ('Pimiento verde', 'Frutas y verduras', '🫑', 'ud'),
  ('Calabacín', 'Frutas y verduras', '🥒', 'ud'),
  ('Berenjena', 'Frutas y verduras', '🍆', 'ud'),
  ('Pepino', 'Frutas y verduras', '🥒', 'ud'),
  ('Brócoli', 'Frutas y verduras', '🥦', 'ud'),
  ('Coliflor', 'Frutas y verduras', '🥦', 'ud'),
  ('Espinacas', 'Frutas y verduras', '🥬', 'ud'),
  ('Rúcula', 'Frutas y verduras', '🥬', 'ud'),
  ('Canónigos', 'Frutas y verduras', '🥬', 'ud'),
  ('Champiñones', 'Frutas y verduras', '🍄', 'ud'),
  ('Puerro', 'Frutas y verduras', '🧅', 'ud'),
  ('Apio', 'Frutas y verduras', '🥬', 'ud'),
  ('Calabaza', 'Frutas y verduras', '🎃', 'kg'),
  ('Judías verdes', 'Frutas y verduras', '🫛', 'ud'),
  ('Guisantes frescos', 'Frutas y verduras', '🫛', 'ud'),
  ('Maíz dulce', 'Frutas y verduras', '🌽', 'ud'),
  ('Aguacate', 'Frutas y verduras', '🥑', 'ud'),
  ('Limón', 'Frutas y verduras', '🍋', 'ud'),
  ('Lima', 'Frutas y verduras', '🍋', 'ud'),
  ('Naranja', 'Frutas y verduras', '🍊', 'kg'),
  ('Mandarina', 'Frutas y verduras', '🍊', 'kg'),
  ('Manzana', 'Frutas y verduras', '🍎', 'kg'),
  ('Pera', 'Frutas y verduras', '🍐', 'kg'),
  ('Plátano', 'Frutas y verduras', '🍌', 'kg'),
  ('Fresas', 'Frutas y verduras', '🍓', 'ud'),
  ('Uvas', 'Frutas y verduras', '🍇', 'ud'),
  ('Kiwi', 'Frutas y verduras', '🥝', 'ud'),
  ('Melón', 'Frutas y verduras', '🍈', 'ud'),
  ('Sandía', 'Frutas y verduras', '🍉', 'ud'),
  ('Piña', 'Frutas y verduras', '🍍', 'ud'),
  ('Melocotón', 'Frutas y verduras', '🍑', 'kg'),
  ('Mango', 'Frutas y verduras', '🥭', 'ud'),
  ('Cerezas', 'Frutas y verduras', '🍒', 'ud'),
  ('Arándanos', 'Frutas y verduras', '🫐', 'ud'),
  ('Frambuesas', 'Frutas y verduras', '🫐', 'ud'),
  ('Perejil', 'Frutas y verduras', '🌿', 'ud'),
  ('Cilantro', 'Frutas y verduras', '🌿', 'ud'),
  ('Albahaca', 'Frutas y verduras', '🌿', 'ud'),
  ('Jengibre', 'Frutas y verduras', '🫚', 'ud'),
  ('Ensalada en bolsa', 'Frutas y verduras', '🥗', 'ud'),
  ('Pechuga de pollo', 'Carnes y pescados', '🍗', 'kg'),
  ('Muslos de pollo', 'Carnes y pescados', '🍗', 'kg'),
  ('Pollo entero', 'Carnes y pescados', '🐔', 'ud'),
  ('Alitas de pollo', 'Carnes y pescados', '🍗', 'ud'),
  ('Carne picada', 'Carnes y pescados', '🥩', 'kg'),
  ('Filetes de ternera', 'Carnes y pescados', '🥩', 'ud'),
  ('Lomo de cerdo', 'Carnes y pescados', '🥩', 'ud'),
  ('Costillas de cerdo', 'Carnes y pescados', '🍖', 'ud'),
  ('Chuletas de cerdo', 'Carnes y pescados', '🍖', 'ud'),
  ('Secreto ibérico', 'Carnes y pescados', '🥩', 'ud'),
  ('Hamburguesas', 'Carnes y pescados', '🍔', 'ud'),
  ('Salchichas', 'Carnes y pescados', '🌭', 'ud'),
  ('Pavo en filetes', 'Carnes y pescados', '🍗', 'ud'),
  ('Cordero', 'Carnes y pescados', '🍖', 'ud'),
  ('Conejo', 'Carnes y pescados', '🍖', 'ud'),
  ('Merluza', 'Carnes y pescados', '🐟', 'ud'),
  ('Salmón', 'Carnes y pescados', '🐟', 'ud'),
  ('Bacalao', 'Carnes y pescados', '🐟', 'ud'),
  ('Dorada', 'Carnes y pescados', '🐟', 'ud'),
  ('Lubina', 'Carnes y pescados', '🐟', 'ud'),
  ('Atún fresco', 'Carnes y pescados', '🐟', 'ud'),
  ('Sardinas', 'Carnes y pescados', '🐟', 'ud'),
  ('Boquerones', 'Carnes y pescados', '🐟', 'ud'),
  ('Gambas', 'Carnes y pescados', '🦐', 'ud'),
  ('Langostinos', 'Carnes y pescados', '🦐', 'ud'),
  ('Calamares', 'Carnes y pescados', '🦑', 'ud'),
  ('Sepia', 'Carnes y pescados', '🦑', 'ud'),
  ('Mejillones', 'Carnes y pescados', '🦪', 'ud'),
  ('Almejas', 'Carnes y pescados', '🦪', 'ud'),
  ('Jamón serrano', 'Charcutería y quesos', '🥓', 'ud'),
  ('Jamón cocido', 'Charcutería y quesos', '🥓', 'ud'),
  ('Pechuga de pavo', 'Charcutería y quesos', '🥓', 'ud'),
  ('Chorizo', 'Charcutería y quesos', '🌭', 'ud'),
  ('Salchichón', 'Charcutería y quesos', '🌭', 'ud'),
  ('Fuet', 'Charcutería y quesos', '🌭', 'ud'),
  ('Lomo embuchado', 'Charcutería y quesos', '🥓', 'ud'),
  ('Bacon', 'Charcutería y quesos', '🥓', 'ud'),
  ('Mortadela', 'Charcutería y quesos', '🥓', 'ud'),
  ('Queso en lonchas', 'Charcutería y quesos', '🧀', 'ud'),
  ('Queso curado', 'Charcutería y quesos', '🧀', 'ud'),
  ('Queso semicurado', 'Charcutería y quesos', '🧀', 'ud'),
  ('Queso fresco', 'Charcutería y quesos', '🧀', 'ud'),
  ('Queso rallado', 'Charcutería y quesos', '🧀', 'ud'),
  ('Mozzarella', 'Charcutería y quesos', '🧀', 'ud'),
  ('Queso de untar', 'Charcutería y quesos', '🧀', 'ud'),
  ('Quesitos', 'Charcutería y quesos', '🧀', 'ud'),
  ('Parmesano', 'Charcutería y quesos', '🧀', 'ud'),
  ('Queso de cabra', 'Charcutería y quesos', '🧀', 'ud'),
  ('Leche entera', 'Lácteos y huevos', '🥛', 'l'),
  ('Leche semidesnatada', 'Lácteos y huevos', '🥛', 'l'),
  ('Leche desnatada', 'Lácteos y huevos', '🥛', 'l'),
  ('Bebida de avena', 'Lácteos y huevos', '🥛', 'l'),
  ('Bebida de soja', 'Lácteos y huevos', '🥛', 'l'),
  ('Huevos', 'Lácteos y huevos', '🥚', 'ud'),
  ('Yogur natural', 'Lácteos y huevos', '🥣', 'ud'),
  ('Yogures de sabores', 'Lácteos y huevos', '🥣', 'ud'),
  ('Yogur griego', 'Lácteos y huevos', '🥣', 'ud'),
  ('Kéfir', 'Lácteos y huevos', '🥛', 'ud'),
  ('Natillas', 'Lácteos y huevos', '🍮', 'ud'),
  ('Flan', 'Lácteos y huevos', '🍮', 'ud'),
  ('Mantequilla', 'Lácteos y huevos', '🧈', 'ud'),
  ('Nata para cocinar', 'Lácteos y huevos', '🥛', 'ud'),
  ('Nata para montar', 'Lácteos y huevos', '🥛', 'ud'),
  ('Batidos', 'Lácteos y huevos', '🥤', 'ud'),
  ('Petit suisse', 'Lácteos y huevos', '🥣', 'ud'),
  ('Pan de barra', 'Panadería', '🥖', 'ud'),
  ('Pan de molde', 'Panadería', '🍞', 'ud'),
  ('Pan integral', 'Panadería', '🍞', 'ud'),
  ('Pan de hamburguesa', 'Panadería', '🍔', 'ud'),
  ('Pan de perrito', 'Panadería', '🌭', 'ud'),
  ('Tortillas de trigo', 'Panadería', '🫓', 'ud'),
  ('Pan tostado', 'Panadería', '🍞', 'ud'),
  ('Picos', 'Panadería', '🥖', 'ud'),
  ('Biscotes', 'Panadería', '🍞', 'ud'),
  ('Croissants', 'Panadería', '🥐', 'ud'),
  ('Magdalenas', 'Panadería', '🧁', 'ud'),
  ('Bizcocho', 'Panadería', '🍰', 'ud'),
  ('Macarrones', 'Pasta, arroz y legumbres', '🍝', 'ud'),
  ('Espaguetis', 'Pasta, arroz y legumbres', '🍝', 'ud'),
  ('Tallarines', 'Pasta, arroz y legumbres', '🍝', 'ud'),
  ('Fideos', 'Pasta, arroz y legumbres', '🍜', 'ud'),
  ('Lasaña (placas)', 'Pasta, arroz y legumbres', '🍝', 'ud'),
  ('Arroz redondo', 'Pasta, arroz y legumbres', '🍚', 'kg'),
  ('Arroz largo', 'Pasta, arroz y legumbres', '🍚', 'kg'),
  ('Arroz basmati', 'Pasta, arroz y legumbres', '🍚', 'ud'),
  ('Lentejas', 'Pasta, arroz y legumbres', '🫘', 'ud'),
  ('Garbanzos', 'Pasta, arroz y legumbres', '🫘', 'ud'),
  ('Alubias', 'Pasta, arroz y legumbres', '🫘', 'ud'),
  ('Garbanzos cocidos', 'Pasta, arroz y legumbres', '🫘', 'ud'),
  ('Lentejas cocidas', 'Pasta, arroz y legumbres', '🫘', 'ud'),
  ('Cuscús', 'Pasta, arroz y legumbres', '🍚', 'ud'),
  ('Quinoa', 'Pasta, arroz y legumbres', '🍚', 'ud'),
  ('Harina', 'Pasta, arroz y legumbres', '🌾', 'kg'),
  ('Pan rallado', 'Pasta, arroz y legumbres', '🍞', 'ud'),
  ('Puré de patata', 'Pasta, arroz y legumbres', '🥔', 'ud'),
  ('Caldo de pollo', 'Pasta, arroz y legumbres', '🍲', 'l'),
  ('Caldo de verduras', 'Pasta, arroz y legumbres', '🍲', 'l'),
  ('Sopa de sobre', 'Pasta, arroz y legumbres', '🍜', 'ud'),
  ('Aceite de oliva virgen extra', 'Aceites, salsas y especias', '🫒', 'l'),
  ('Aceite de oliva', 'Aceites, salsas y especias', '🫒', 'l'),
  ('Aceite de girasol', 'Aceites, salsas y especias', '🌻', 'l'),
  ('Vinagre', 'Aceites, salsas y especias', '🍶', 'ud'),
  ('Sal', 'Aceites, salsas y especias', '🧂', 'ud'),
  ('Pimienta', 'Aceites, salsas y especias', '🧂', 'ud'),
  ('Pimentón', 'Aceites, salsas y especias', '🌶️', 'ud'),
  ('Orégano', 'Aceites, salsas y especias', '🌿', 'ud'),
  ('Comino', 'Aceites, salsas y especias', '🧂', 'ud'),
  ('Curry', 'Aceites, salsas y especias', '🍛', 'ud'),
  ('Azafrán', 'Aceites, salsas y especias', '🌼', 'ud'),
  ('Colorante alimentario', 'Aceites, salsas y especias', '🌼', 'ud'),
  ('Laurel', 'Aceites, salsas y especias', '🌿', 'ud'),
  ('Tomate frito', 'Aceites, salsas y especias', '🥫', 'ud'),
  ('Tomate triturado', 'Aceites, salsas y especias', '🥫', 'ud'),
  ('Mayonesa', 'Aceites, salsas y especias', '🥚', 'ud'),
  ('Ketchup', 'Aceites, salsas y especias', '🍅', 'ud'),
  ('Mostaza', 'Aceites, salsas y especias', '🌭', 'ud'),
  ('Salsa de soja', 'Aceites, salsas y especias', '🍶', 'ud'),
  ('Alioli', 'Aceites, salsas y especias', '🧄', 'ud'),
  ('Pesto', 'Aceites, salsas y especias', '🌿', 'ud'),
  ('Salsa barbacoa', 'Aceites, salsas y especias', '🍖', 'ud'),
  ('Avecrem', 'Aceites, salsas y especias', '🍲', 'ud'),
  ('Atún en lata', 'Conservas', '🥫', 'ud'),
  ('Sardinas en lata', 'Conservas', '🥫', 'ud'),
  ('Mejillones en escabeche', 'Conservas', '🥫', 'ud'),
  ('Berberechos', 'Conservas', '🥫', 'ud'),
  ('Aceitunas', 'Conservas', '🫒', 'ud'),
  ('Maíz en lata', 'Conservas', '🌽', 'ud'),
  ('Pimientos del piquillo', 'Conservas', '🫑', 'ud'),
  ('Espárragos', 'Conservas', '🥫', 'ud'),
  ('Alcachofas en conserva', 'Conservas', '🥫', 'ud'),
  ('Melocotón en almíbar', 'Conservas', '🍑', 'ud'),
  ('Pepinillos', 'Conservas', '🥒', 'ud'),
  ('Paté', 'Conservas', '🥫', 'ud'),
  ('Café molido', 'Desayuno y dulces', '☕', 'ud'),
  ('Café en cápsulas', 'Desayuno y dulces', '☕', 'ud'),
  ('Café soluble', 'Desayuno y dulces', '☕', 'ud'),
  ('Cacao en polvo', 'Desayuno y dulces', '🍫', 'ud'),
  ('Infusiones', 'Desayuno y dulces', '🍵', 'ud'),
  ('Té', 'Desayuno y dulces', '🍵', 'ud'),
  ('Cereales', 'Desayuno y dulces', '🥣', 'ud'),
  ('Copos de avena', 'Desayuno y dulces', '🥣', 'ud'),
  ('Galletas', 'Desayuno y dulces', '🍪', 'ud'),
  ('Galletas María', 'Desayuno y dulces', '🍪', 'ud'),
  ('Tostadas de arroz', 'Desayuno y dulces', '🍘', 'ud'),
  ('Mermelada', 'Desayuno y dulces', '🍓', 'ud'),
  ('Miel', 'Desayuno y dulces', '🍯', 'ud'),
  ('Crema de cacao', 'Desayuno y dulces', '🍫', 'ud'),
  ('Azúcar', 'Desayuno y dulces', '🍬', 'kg'),
  ('Edulcorante', 'Desayuno y dulces', '🍬', 'ud'),
  ('Chocolate', 'Desayuno y dulces', '🍫', 'ud'),
  ('Frutos secos', 'Desayuno y dulces', '🥜', 'ud'),
  ('Patatas fritas', 'Desayuno y dulces', '🥔', 'ud'),
  ('Gusanitos', 'Desayuno y dulces', '🥨', 'ud'),
  ('Palomitas', 'Desayuno y dulces', '🍿', 'ud'),
  ('Chucherías', 'Desayuno y dulces', '🍬', 'ud'),
  ('Barritas de cereales', 'Desayuno y dulces', '🥣', 'ud'),
  ('Guisantes congelados', 'Congelados', '🫛', 'ud'),
  ('Verduras congeladas', 'Congelados', '🥦', 'ud'),
  ('Patatas fritas congeladas', 'Congelados', '🍟', 'ud'),
  ('Pizza congelada', 'Congelados', '🍕', 'ud'),
  ('Croquetas', 'Congelados', '🧆', 'ud'),
  ('Varitas de merluza', 'Congelados', '🐟', 'ud'),
  ('San Jacobos', 'Congelados', '🧆', 'ud'),
  ('Nuggets', 'Congelados', '🍗', 'ud'),
  ('Empanadillas', 'Congelados', '🥟', 'ud'),
  ('Gambas congeladas', 'Congelados', '🦐', 'ud'),
  ('Helado', 'Congelados', '🍨', 'ud'),
  ('Hielo', 'Congelados', '🧊', 'ud'),
  ('Masa de hojaldre', 'Congelados', '🥐', 'ud'),
  ('Masa de pizza', 'Congelados', '🍕', 'ud'),
  ('Agua', 'Bebidas', '💧', 'l'),
  ('Agua con gas', 'Bebidas', '💧', 'ud'),
  ('Refresco de cola', 'Bebidas', '🥤', 'ud'),
  ('Refresco de naranja', 'Bebidas', '🥤', 'ud'),
  ('Refresco de limón', 'Bebidas', '🥤', 'ud'),
  ('Tónica', 'Bebidas', '🥤', 'ud'),
  ('Zumo de naranja', 'Bebidas', '🧃', 'l'),
  ('Zumo de melocotón', 'Bebidas', '🧃', 'ud'),
  ('Cerveza', 'Bebidas', '🍺', 'ud'),
  ('Cerveza sin alcohol', 'Bebidas', '🍺', 'ud'),
  ('Vino tinto', 'Bebidas', '🍷', 'ud'),
  ('Vino blanco', 'Bebidas', '🍷', 'ud'),
  ('Cava', 'Bebidas', '🍾', 'ud'),
  ('Bebida isotónica', 'Bebidas', '🥤', 'ud'),
  ('Horchata', 'Bebidas', '🥛', 'ud'),
  ('Detergente', 'Limpieza', '🧴', 'ud'),
  ('Suavizante', 'Limpieza', '🧴', 'ud'),
  ('Lavavajillas a mano', 'Limpieza', '🧽', 'ud'),
  ('Pastillas lavavajillas', 'Limpieza', '🧼', 'ud'),
  ('Sal lavavajillas', 'Limpieza', '🧂', 'ud'),
  ('Abrillantador lavavajillas', 'Limpieza', '✨', 'ud'),
  ('Lejía', 'Limpieza', '🧴', 'ud'),
  ('Friegasuelos', 'Limpieza', '🪣', 'ud'),
  ('Limpiacristales', 'Limpieza', '🧴', 'ud'),
  ('Multiusos', 'Limpieza', '🧴', 'ud'),
  ('Desengrasante', 'Limpieza', '🧴', 'ud'),
  ('Quitagrasas', 'Limpieza', '🧴', 'ud'),
  ('Limpiador de baño', 'Limpieza', '🚽', 'ud'),
  ('Gel WC', 'Limpieza', '🚽', 'ud'),
  ('Estropajos', 'Limpieza', '🧽', 'ud'),
  ('Bayetas', 'Limpieza', '🧽', 'ud'),
  ('Fregona', 'Limpieza', '🪣', 'ud'),
  ('Guantes de limpieza', 'Limpieza', '🧤', 'ud'),
  ('Papel de cocina', 'Limpieza', '🧻', 'ud'),
  ('Bolsas de basura', 'Limpieza', '🗑️', 'ud'),
  ('Papel de aluminio', 'Limpieza', '🧻', 'ud'),
  ('Papel film', 'Limpieza', '🧻', 'ud'),
  ('Papel de horno', 'Limpieza', '🧻', 'ud'),
  ('Bolsas de congelación', 'Limpieza', '🛍️', 'ud'),
  ('Ambientador', 'Limpieza', '🌸', 'ud'),
  ('Insecticida', 'Limpieza', '🪰', 'ud'),
  ('Quitamanchas', 'Limpieza', '🧴', 'ud'),
  ('Pinzas de ropa', 'Limpieza', '🧺', 'ud'),
  ('Papel higiénico', 'Higiene y cuidado', '🧻', 'ud'),
  ('Gel de ducha', 'Higiene y cuidado', '🧴', 'ud'),
  ('Champú', 'Higiene y cuidado', '🧴', 'ud'),
  ('Acondicionador', 'Higiene y cuidado', '🧴', 'ud'),
  ('Pasta de dientes', 'Higiene y cuidado', '🪥', 'ud'),
  ('Cepillo de dientes', 'Higiene y cuidado', '🪥', 'ud'),
  ('Enjuague bucal', 'Higiene y cuidado', '🧴', 'ud'),
  ('Hilo dental', 'Higiene y cuidado', '🪥', 'ud'),
  ('Desodorante', 'Higiene y cuidado', '🧴', 'ud'),
  ('Jabón de manos', 'Higiene y cuidado', '🧼', 'ud'),
  ('Crema hidratante', 'Higiene y cuidado', '🧴', 'ud'),
  ('Protector solar', 'Higiene y cuidado', '🧴', 'ud'),
  ('Cuchillas de afeitar', 'Higiene y cuidado', '🪒', 'ud'),
  ('Espuma de afeitar', 'Higiene y cuidado', '🧴', 'ud'),
  ('Compresas', 'Higiene y cuidado', '🩹', 'ud'),
  ('Tampones', 'Higiene y cuidado', '🩹', 'ud'),
  ('Bastoncillos', 'Higiene y cuidado', '🦯', 'ud'),
  ('Algodón', 'Higiene y cuidado', '☁️', 'ud'),
  ('Pañuelos de papel', 'Higiene y cuidado', '🤧', 'ud'),
  ('Toallitas desmaquillantes', 'Higiene y cuidado', '🧻', 'ud'),
  ('Laca', 'Higiene y cuidado', '🧴', 'ud'),
  ('Gomas del pelo', 'Higiene y cuidado', '🎀', 'ud'),
  ('Colonia', 'Higiene y cuidado', '🧴', 'ud'),
  ('Pañales', 'Bebé', '🍼', 'ud'),
  ('Toallitas bebé', 'Bebé', '🧻', 'ud'),
  ('Leche de fórmula', 'Bebé', '🍼', 'ud'),
  ('Potitos', 'Bebé', '🍼', 'ud'),
  ('Papilla de cereales', 'Bebé', '🥣', 'ud'),
  ('Crema del pañal', 'Bebé', '🧴', 'ud'),
  ('Champú infantil', 'Bebé', '🧴', 'ud'),
  ('Colonia infantil', 'Bebé', '🧴', 'ud'),
  ('Pienso perro', 'Mascotas', '🐶', 'kg'),
  ('Pienso gato', 'Mascotas', '🐱', 'kg'),
  ('Comida húmeda perro', 'Mascotas', '🐶', 'ud'),
  ('Comida húmeda gato', 'Mascotas', '🐱', 'ud'),
  ('Arena para gato', 'Mascotas', '🐱', 'ud'),
  ('Premios mascota', 'Mascotas', '🦴', 'ud'),
  ('Bolsas para excrementos', 'Mascotas', '🐾', 'ud'),
  ('Paracetamol', 'Farmacia', '💊', 'ud'),
  ('Ibuprofeno', 'Farmacia', '💊', 'ud'),
  ('Tiritas', 'Farmacia', '🩹', 'ud'),
  ('Termómetro', 'Farmacia', '🌡️', 'ud'),
  ('Suero fisiológico', 'Farmacia', '💧', 'ud'),
  ('Alcohol', 'Farmacia', '🧴', 'ud'),
  ('Agua oxigenada', 'Farmacia', '🧴', 'ud'),
  ('Gasas', 'Farmacia', '🩹', 'ud'),
  ('Antimosquitos', 'Farmacia', '🦟', 'ud'),
  ('Vitaminas', 'Farmacia', '💊', 'ud'),
  ('Mascarillas', 'Farmacia', '😷', 'ud'),
  ('Bombillas', 'Hogar y bricolaje', '💡', 'ud'),
  ('Pilas AA', 'Hogar y bricolaje', '🔋', 'ud'),
  ('Pilas AAA', 'Hogar y bricolaje', '🔋', 'ud'),
  ('Pila de botón', 'Hogar y bricolaje', '🔋', 'ud'),
  ('Cinta americana', 'Hogar y bricolaje', '🧰', 'ud'),
  ('Celo', 'Hogar y bricolaje', '🧰', 'ud'),
  ('Pegamento', 'Hogar y bricolaje', '🧴', 'ud'),
  ('Tornillos', 'Hogar y bricolaje', '🔩', 'ud'),
  ('Tacos', 'Hogar y bricolaje', '🔩', 'ud'),
  ('Alcargolas', 'Hogar y bricolaje', '🔩', 'ud'),
  ('Cuerda', 'Hogar y bricolaje', '🪢', 'ud'),
  ('Cajas de cartón', 'Hogar y bricolaje', '📦', 'ud'),
  ('Cajas de almacenaje', 'Hogar y bricolaje', '📦', 'ud'),
  ('Perchas', 'Hogar y bricolaje', '🧥', 'ud'),
  ('Velas', 'Hogar y bricolaje', '🕯️', 'ud'),
  ('Cerillas', 'Hogar y bricolaje', '🔥', 'ud'),
  ('Mechero', 'Hogar y bricolaje', '🔥', 'ud'),
  ('Toallas', 'Hogar y bricolaje', '🛁', 'ud'),
  ('Sábanas', 'Hogar y bricolaje', '🛏️', 'ud'),
  ('Almohada', 'Hogar y bricolaje', '🛏️', 'ud'),
  ('Cubiertos', 'Hogar y bricolaje', '🍴', 'ud'),
  ('Vasos', 'Hogar y bricolaje', '🥛', 'ud'),
  ('Platos', 'Hogar y bricolaje', '🍽️', 'ud'),
  ('Tupper', 'Hogar y bricolaje', '🥡', 'ud'),
  ('Sartén', 'Hogar y bricolaje', '🍳', 'ud'),
  ('Cazo', 'Hogar y bricolaje', '🍲', 'ud'),
  ('Fregona de repuesto', 'Hogar y bricolaje', '🪣', 'ud'),
  ('Escoba', 'Hogar y bricolaje', '🧹', 'ud'),
  ('Recogedor', 'Hogar y bricolaje', '🧹', 'ud'),
  ('Cubo de basura', 'Hogar y bricolaje', '🗑️', 'ud'),
  ('Felpudo', 'Hogar y bricolaje', '🚪', 'ud'),
  ('Plantas', 'Hogar y bricolaje', '🪴', 'ud'),
  ('Tierra para plantas', 'Hogar y bricolaje', '🪴', 'ud'),
  ('Alfombra', 'Hogar y bricolaje', '🟫', 'ud'),
  ('Cortinas', 'Hogar y bricolaje', '🪟', 'ud'),
  ('Regleta', 'Hogar y bricolaje', '🔌', 'ud'),
  ('Alargador', 'Hogar y bricolaje', '🔌', 'ud'),
  ('Folios', 'Papelería y oficina', '📄', 'ud'),
  ('Cuaderno', 'Papelería y oficina', '📓', 'ud'),
  ('Libreta', 'Papelería y oficina', '📒', 'ud'),
  ('Bolígrafos', 'Papelería y oficina', '🖊️', 'ud'),
  ('Lápices', 'Papelería y oficina', '✏️', 'ud'),
  ('Gomas de borrar', 'Papelería y oficina', '🩹', 'ud'),
  ('Sacapuntas', 'Papelería y oficina', '✏️', 'ud'),
  ('Rotuladores', 'Papelería y oficina', '🖍️', 'ud'),
  ('Ceras', 'Papelería y oficina', '🖍️', 'ud'),
  ('Pinturas de colores', 'Papelería y oficina', '🖍️', 'ud'),
  ('Tijeras', 'Papelería y oficina', '✂️', 'ud'),
  ('Pegamento de barra', 'Papelería y oficina', '🧴', 'ud'),
  ('Cartulinas', 'Papelería y oficina', '📄', 'ud'),
  ('Carpetas', 'Papelería y oficina', '📁', 'ud'),
  ('Fundas de plástico', 'Papelería y oficina', '📁', 'ud'),
  ('Post-it', 'Papelería y oficina', '🗒️', 'ud'),
  ('Grapas', 'Papelería y oficina', '📎', 'ud'),
  ('Clips', 'Papelería y oficina', '📎', 'ud'),
  ('Sobres', 'Papelería y oficina', '✉️', 'ud'),
  ('Cinta adhesiva', 'Papelería y oficina', '🧰', 'ud'),
  ('Cartuchos de tinta', 'Papelería y oficina', '🖨️', 'ud'),
  ('Plastilina', 'Papelería y oficina', '🎨', 'ud'),
  ('Acuarelas', 'Papelería y oficina', '🎨', 'ud'),
  ('Mochila', 'Papelería y oficina', '🎒', 'ud'),
  ('Estuche', 'Papelería y oficina', '✏️', 'ud'),
  ('Agenda', 'Papelería y oficina', '📅', 'ud'),
  ('Zapatos', 'Ropa y calzado', '👞', 'ud'),
  ('Zapatillas', 'Ropa y calzado', '👟', 'ud'),
  ('Zapatillas de casa', 'Ropa y calzado', '🥿', 'ud'),
  ('Sandalias', 'Ropa y calzado', '🩴', 'ud'),
  ('Botas', 'Ropa y calzado', '👢', 'ud'),
  ('Calcetines', 'Ropa y calzado', '🧦', 'ud'),
  ('Ropa interior', 'Ropa y calzado', '🩲', 'ud'),
  ('Pijama', 'Ropa y calzado', '👕', 'ud'),
  ('Camisetas', 'Ropa y calzado', '👕', 'ud'),
  ('Pantalones', 'Ropa y calzado', '👖', 'ud'),
  ('Chándal', 'Ropa y calzado', '👖', 'ud'),
  ('Sudadera', 'Ropa y calzado', '🧥', 'ud'),
  ('Abrigo', 'Ropa y calzado', '🧥', 'ud'),
  ('Chubasquero', 'Ropa y calzado', '🧥', 'ud'),
  ('Gorro', 'Ropa y calzado', '🧢', 'ud'),
  ('Guantes', 'Ropa y calzado', '🧤', 'ud'),
  ('Bufanda', 'Ropa y calzado', '🧣', 'ud'),
  ('Bañador', 'Ropa y calzado', '🩱', 'ud'),
  ('Cordones', 'Ropa y calzado', '👟', 'ud'),
  ('Betún', 'Ropa y calzado', '🥾', 'ud'),
  ('Cargador móvil', 'Electrónica', '🔌', 'ud'),
  ('Cable USB', 'Electrónica', '🔌', 'ud'),
  ('Auriculares', 'Electrónica', '🎧', 'ud'),
  ('Funda móvil', 'Electrónica', '📱', 'ud'),
  ('Ratón', 'Electrónica', '🖱️', 'ud'),
  ('Pendrive', 'Electrónica', '💾', 'ud'),
  ('Tarjeta de memoria', 'Electrónica', '💾', 'ud'),
  ('Bombilla inteligente', 'Electrónica', '💡', 'ud'),
  ('Pilas recargables', 'Electrónica', '🔋', 'ud'),
  ('Mando a distancia', 'Electrónica', '📺', 'ud'),
  ('Regalo', 'Otros', '🎁', 'ud'),
  ('Flores', 'Otros', '💐', 'ud'),
  ('Lotería', 'Otros', '🎟️', 'ud'),
  ('Recambio', 'Otros', '📦', 'ud'),
  ('Bolsa reutilizable', 'Otros', '🛍️', 'ud')
on conflict (nombre) do nothing;
insert into public.recetas_base (nombre, emoji, minutos, momento, ingredientes) values
  ('Avena con fruta', '🥣', 10, 'desayuno', '[{"nombre": "Copos de avena", "cant": 80, "unidad": "g"}, {"nombre": "Leche semidesnatada", "cant": 0.3, "unidad": "l"}, {"nombre": "Plátano", "cant": 1, "unidad": "ud"}, {"nombre": "Fresas", "cant": 1, "unidad": "ud"}, {"nombre": "Miel", "cant": 1, "unidad": "ud"}]'::jsonb),
  ('Tostadas con tomate y aceite', '🍞', 10, 'desayuno', '[{"nombre": "Pan de barra", "cant": 1, "unidad": "ud"}, {"nombre": "Tomate", "cant": 0.3, "unidad": "kg"}, {"nombre": "Aceite de oliva virgen extra", "cant": 1, "unidad": "ud"}]'::jsonb),
  ('Yogur con cereales', '🥣', 5, 'desayuno', '[{"nombre": "Yogur natural", "cant": 3, "unidad": "ud"}, {"nombre": "Cereales", "cant": 1, "unidad": "ud"}]'::jsonb),
  ('Pollo al horno con verduras', '🍗', 40, 'comida', '[{"nombre": "Muslos de pollo", "cant": 1, "unidad": "kg"}, {"nombre": "Patata", "cant": 0.6, "unidad": "kg"}, {"nombre": "Pimiento rojo", "cant": 1, "unidad": "ud"}, {"nombre": "Cebolla", "cant": 1, "unidad": "ud"}, {"nombre": "Limón", "cant": 1, "unidad": "ud"}]'::jsonb),
  ('Macarrones con tomate', '🍝', 25, 'comida', '[{"nombre": "Macarrones", "cant": 400, "unidad": "g"}, {"nombre": "Tomate frito", "cant": 1, "unidad": "ud"}, {"nombre": "Carne picada", "cant": 0.25, "unidad": "kg"}, {"nombre": "Cebolla", "cant": 1, "unidad": "ud"}, {"nombre": "Queso rallado", "cant": 1, "unidad": "ud"}]'::jsonb),
  ('Lentejas con verduras', '🍲', 45, 'comida', '[{"nombre": "Lentejas", "cant": 300, "unidad": "g"}, {"nombre": "Zanahoria", "cant": 2, "unidad": "ud"}, {"nombre": "Patata", "cant": 2, "unidad": "ud"}, {"nombre": "Pimiento verde", "cant": 1, "unidad": "ud"}, {"nombre": "Chorizo", "cant": 1, "unidad": "ud"}]'::jsonb),
  ('Paella de pollo y verduras', '🥘', 50, 'comida', '[{"nombre": "Arroz redondo", "cant": 0.4, "unidad": "kg"}, {"nombre": "Muslos de pollo", "cant": 0.5, "unidad": "kg"}, {"nombre": "Judías verdes", "cant": 1, "unidad": "ud"}, {"nombre": "Tomate triturado", "cant": 1, "unidad": "ud"}, {"nombre": "Azafrán", "cant": 1, "unidad": "ud"}]'::jsonb),
  ('Merluza al horno con patatas', '🐟', 35, 'comida', '[{"nombre": "Merluza", "cant": 0.6, "unidad": "kg"}, {"nombre": "Patata", "cant": 0.5, "unidad": "kg"}, {"nombre": "Limón", "cant": 1, "unidad": "ud"}, {"nombre": "Ajo", "cant": 1, "unidad": "ud"}]'::jsonb),
  ('Garbanzos con espinacas', '🫘', 30, 'comida', '[{"nombre": "Garbanzos cocidos", "cant": 2, "unidad": "ud"}, {"nombre": "Espinacas", "cant": 1, "unidad": "ud"}, {"nombre": "Ajo", "cant": 1, "unidad": "ud"}, {"nombre": "Pimentón", "cant": 1, "unidad": "ud"}]'::jsonb),
  ('Tortilla de patatas', '🍳', 35, 'cena', '[{"nombre": "Huevos", "cant": 6, "unidad": "ud"}, {"nombre": "Patata", "cant": 1, "unidad": "kg"}, {"nombre": "Cebolla", "cant": 1, "unidad": "ud"}]'::jsonb),
  ('Crema de calabaza', '🎃', 30, 'cena', '[{"nombre": "Calabaza", "cant": 1, "unidad": "kg"}, {"nombre": "Patata", "cant": 1, "unidad": "ud"}, {"nombre": "Cebolla", "cant": 1, "unidad": "ud"}, {"nombre": "Quesitos", "cant": 1, "unidad": "ud"}]'::jsonb),
  ('Revuelto de espinacas', '🥬', 20, 'cena', '[{"nombre": "Espinacas", "cant": 1, "unidad": "ud"}, {"nombre": "Huevos", "cant": 4, "unidad": "ud"}, {"nombre": "Ajo", "cant": 1, "unidad": "ud"}]'::jsonb),
  ('Salmón a la plancha con ensalada', '🐟', 20, 'cena', '[{"nombre": "Salmón", "cant": 0.5, "unidad": "kg"}, {"nombre": "Ensalada en bolsa", "cant": 1, "unidad": "ud"}, {"nombre": "Tomate cherry", "cant": 1, "unidad": "ud"}]'::jsonb),
  ('Sándwiches y fruta', '🥪', 10, 'cena', '[{"nombre": "Pan de molde", "cant": 1, "unidad": "ud"}, {"nombre": "Jamón cocido", "cant": 1, "unidad": "ud"}, {"nombre": "Queso en lonchas", "cant": 1, "unidad": "ud"}, {"nombre": "Manzana", "cant": 0.5, "unidad": "kg"}]'::jsonb),
  ('Pizza casera', '🍕', 30, 'cena', '[{"nombre": "Masa de pizza", "cant": 1, "unidad": "ud"}, {"nombre": "Tomate frito", "cant": 1, "unidad": "ud"}, {"nombre": "Mozzarella", "cant": 1, "unidad": "ud"}, {"nombre": "Jamón cocido", "cant": 1, "unidad": "ud"}]'::jsonb)
on conflict (nombre) do nothing;
