-- Savium Rewards v1: cartera familiar de tarjetas de fidelidad.
-- Vive en el proyecto de Savium Finanzas; todo lleva el prefijo rewards_ y solo referencia auth.users,
-- para poder moverlo a su propio proyecto al lanzar.

-- MARK: Tablas

create table public.rewards_familias (
  id uuid primary key default gen_random_uuid(),
  nombre text not null check (char_length(nombre) between 1 and 60),
  creada timestamptz not null default now()
);

create table public.rewards_miembros (
  user_id uuid primary key references auth.users (id) on delete cascade,
  familia_id uuid not null references public.rewards_familias (id) on delete cascade,
  nombre text not null check (char_length(nombre) between 1 and 40),
  rol text not null default 'miembro' check (rol in ('admin', 'miembro')),
  pais text not null default 'MX' check (pais in ('MX', 'ES')),
  ultima_sincronizacion timestamptz
);
create index rewards_miembros_familia_idx on public.rewards_miembros (familia_id);

create table public.rewards_admins (
  user_id uuid primary key references auth.users (id) on delete cascade
);

create table public.rewards_programas (
  id uuid primary key default gen_random_uuid(),
  nombre text not null check (char_length(nombre) between 1 and 60),
  tipo text not null check (tipo in ('tarjeta_credito', 'aerolinea', 'hotel', 'comercio')),
  pais text not null check (pais in ('MX', 'ES', 'INT')),
  color text not null check (color ~ '^#[0-9A-Fa-f]{6}$'),
  unidad text not null check (char_length(unidad) between 1 and 20),
  codigo_tipo text not null default 'code128'
    check (codigo_tipo in ('qr', 'code128', 'ean13', 'ean8', 'upca', 'code39', 'pdf417', 'aztec', 'ninguno')),
  activo boolean not null default true,
  unique (nombre, pais)
);

create table public.rewards_tarjetas (
  id uuid primary key,
  user_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  programa_id uuid references public.rewards_programas (id) on delete set null,
  nombre text check (char_length(nombre) between 1 and 60),
  color text check (color ~ '^#[0-9A-Fa-f]{6}$'),
  unidad text check (char_length(unidad) between 1 and 20),
  numero_socio text check (char_length(numero_socio) <= 64),
  codigo_valor text check (char_length(codigo_valor) between 1 and 512),
  codigo_tipo text not null default 'ninguno'
    check (codigo_tipo in ('qr', 'code128', 'ean13', 'ean8', 'upca', 'code39', 'pdf417', 'aztec', 'ninguno')),
  titular text check (char_length(titular) <= 60),
  saldo bigint check (saldo between 0 and 1000000000000),
  saldo_fecha date,
  caducidad date,
  notas text check (char_length(notas) <= 1000),
  compartida boolean not null default false,
  orden integer not null default 0,
  actualizado timestamptz not null,
  sincronizado timestamptz not null default now(),
  borrado boolean not null default false,
  -- Sin programa del catálogo hace falta un nombre propio.
  check (programa_id is not null or nombre is not null),
  -- «Sin código» y contenido del código van juntos.
  check ((codigo_tipo = 'ninguno') = (codigo_valor is null))
);
create index rewards_tarjetas_user_sinc_idx on public.rewards_tarjetas (user_id, sincronizado);
create index rewards_tarjetas_programa_idx on public.rewards_tarjetas (programa_id);

-- El servidor marca cuándo llegó cada cambio: es el cursor de descarga de la app.
-- Gana la última edición: una escritura con `actualizado` anterior al guardado (p. ej. un iPhone que estuvo
-- sin conexión) no cambia los datos, pero sí `sincronizado`, para que ese cliente vuelva a bajar la versión
-- vigente y no se quede creyendo que la suya está guardada.
create function public.rewards_marcar_sincronizado() returns trigger
language plpgsql set search_path = '' as $$
begin
  if tg_op = 'UPDATE' and new.actualizado < old.actualizado then
    new := old;
  end if;
  new.sincronizado := clock_timestamp();
  return new;
end $$;

create trigger rewards_tarjetas_sincronizado
  before insert or update on public.rewards_tarjetas
  for each row execute function public.rewards_marcar_sincronizado();

-- MARK: Funciones auxiliares (evitan recursión de RLS en rewards_miembros)

create function public.rewards_mi_familia() returns uuid
language sql stable security definer set search_path = '' as $$
  select familia_id from public.rewards_miembros where user_id = (select auth.uid())
$$;

create function public.rewards_es_admin() returns boolean
language sql stable security definer set search_path = '' as $$
  select exists (select 1 from public.rewards_admins where user_id = (select auth.uid()))
$$;

revoke execute on function public.rewards_mi_familia() from public, anon;
revoke execute on function public.rewards_es_admin() from public, anon;
revoke execute on function public.rewards_marcar_sincronizado() from public, anon, authenticated;
grant execute on function public.rewards_mi_familia() to authenticated;
grant execute on function public.rewards_es_admin() to authenticated;

-- Panel de uso del administrador: solo conteos y datos de miembros, nunca el contenido de tarjetas ajenas.
create function public.rewards_uso() returns jsonb
language plpgsql stable security definer set search_path = '' as $$
begin
  if not public.rewards_es_admin() then
    raise exception 'no_autorizado' using errcode = '42501';
  end if;
  return jsonb_build_object(
    'generado', now(),
    'totales', jsonb_build_object(
      'familias', (select count(*) from public.rewards_familias),
      'miembros', (select count(*) from public.rewards_miembros),
      'tarjetas', (select count(*) from public.rewards_tarjetas where not borrado),
      'compartidas', (select count(*) from public.rewards_tarjetas where not borrado and compartida)
    ),
    'miembros', coalesce((
      select jsonb_agg(jsonb_build_object(
        'user_id', m.user_id, 'nombre', m.nombre, 'email', u.email, 'rol', m.rol, 'pais', m.pais,
        'familia_id', m.familia_id, 'familia', f.nombre,
        'ultima_sincronizacion', m.ultima_sincronizacion, 'ultimo_acceso', u.last_sign_in_at,
        'tarjetas', (select count(*) from public.rewards_tarjetas t where t.user_id = m.user_id and not t.borrado)
      ) order by f.nombre, m.nombre)
      from public.rewards_miembros m
      join public.rewards_familias f on f.id = m.familia_id
      join auth.users u on u.id = m.user_id), '[]'::jsonb),
    'por_programa', coalesce((
      select jsonb_agg(jsonb_build_object('programa', coalesce(p.nombre, 'Otro'), 'tarjetas', n) order by n desc)
      from (select programa_id, count(*) n from public.rewards_tarjetas where not borrado group by 1) t
      left join public.rewards_programas p on p.id = t.programa_id), '[]'::jsonb)
  );
end $$;

revoke execute on function public.rewards_uso() from public, anon;
grant execute on function public.rewards_uso() to authenticated;

-- MARK: Privilegios (mínimos; anon no toca nada)

revoke all on public.rewards_familias, public.rewards_miembros, public.rewards_admins,
  public.rewards_programas, public.rewards_tarjetas from anon, authenticated;

grant select on public.rewards_familias, public.rewards_miembros, public.rewards_admins,
  public.rewards_programas to authenticated;
grant update (nombre, pais, ultima_sincronizacion) on public.rewards_miembros to authenticated;
grant insert, update on public.rewards_programas to authenticated;
grant update (nombre) on public.rewards_familias to authenticated;
grant select, insert, update on public.rewards_tarjetas to authenticated;

-- MARK: RLS

alter table public.rewards_familias enable row level security;
alter table public.rewards_miembros enable row level security;
alter table public.rewards_admins enable row level security;
alter table public.rewards_programas enable row level security;
alter table public.rewards_tarjetas enable row level security;

create policy "Rewards familias: la mía o admin" on public.rewards_familias for select to authenticated
  using (id = (select public.rewards_mi_familia()) or (select public.rewards_es_admin()));
create policy "Rewards familias: renombrar admin" on public.rewards_familias for update to authenticated
  using ((select public.rewards_es_admin())) with check ((select public.rewards_es_admin()));

create policy "Rewards miembros: mi familia o admin" on public.rewards_miembros for select to authenticated
  using (familia_id = (select public.rewards_mi_familia()) or (select public.rewards_es_admin()));
create policy "Rewards miembros: mi fila" on public.rewards_miembros for update to authenticated
  using (user_id = (select auth.uid())) with check (user_id = (select auth.uid()));

create policy "Rewards admins: saber si lo soy" on public.rewards_admins for select to authenticated
  using (user_id = (select auth.uid()));

create policy "Rewards programas: miembros" on public.rewards_programas for select to authenticated
  using ((select public.rewards_mi_familia()) is not null or (select public.rewards_es_admin()));
create policy "Rewards programas: alta admin" on public.rewards_programas for insert to authenticated
  with check ((select public.rewards_es_admin()));
create policy "Rewards programas: cambio admin" on public.rewards_programas for update to authenticated
  using ((select public.rewards_es_admin())) with check ((select public.rewards_es_admin()));

create policy "Rewards tarjetas: mías y compartidas de mi familia" on public.rewards_tarjetas for select to authenticated
  using (
    user_id = (select auth.uid())
    or (compartida and not borrado and exists (
      select 1 from public.rewards_miembros m
      where m.user_id = rewards_tarjetas.user_id and m.familia_id = (select public.rewards_mi_familia())))
  );
create policy "Rewards tarjetas: alta propia" on public.rewards_tarjetas for insert to authenticated
  with check (user_id = (select auth.uid()) and (select public.rewards_mi_familia()) is not null);
create policy "Rewards tarjetas: cambio propio" on public.rewards_tarjetas for update to authenticated
  using (user_id = (select auth.uid())) with check (user_id = (select auth.uid()));
-- Sin política de DELETE: el borrado es lógico (borrado = true).

-- MARK: Borrado de cuenta seguro
-- El proyecto es compartido con Savium Finanzas (y sus tablas tienen ON DELETE CASCADE hacia auth.users):
-- «Eliminar mi cuenta» en Rewards solo borra el usuario de Auth si no tiene NINGUNA fila fuera de rewards_*.
-- Si la tiene, se borran sus datos de Rewards y el usuario de Auth se conserva.
create function public.rewards_usuario_solo_rewards(p_user uuid) returns boolean
language plpgsql stable security definer set search_path = '' as $$
declare
  r record;
  hay boolean;
begin
  for r in
    select n.nspname esquema, c.relname tabla, a.attname columna
    from pg_constraint k
    join pg_class c on c.oid = k.conrelid
    join pg_namespace n on n.oid = c.relnamespace
    join pg_attribute a on a.attrelid = k.conrelid and a.attnum = k.conkey[1]
    where k.contype = 'f' and k.confrelid = 'auth.users'::regclass
      and n.nspname not in ('auth', 'storage', 'realtime', 'supabase_functions', 'vault', 'extensions')
      and c.relname not like 'rewards\_%'
  loop
    execute format('select exists (select 1 from %I.%I where %I = $1)', r.esquema, r.tabla, r.columna)
      into hay using p_user;
    if hay then return false; end if;
  end loop;
  -- Columnas de dueño sin clave foránea declarada (uuid o texto), también en tablas particionadas.
  for r in
    select n.nspname esquema, c.relname tabla, a.attname columna
    from pg_attribute a
    join pg_class c on c.oid = a.attrelid and c.relkind in ('r', 'p')
    join pg_namespace n on n.oid = c.relnamespace and n.nspname = 'public'
    where a.attname in ('user_id', 'propietario_id', 'lector_id', 'owner_id', 'owner')
      and a.atttypid in ('uuid'::regtype, 'text'::regtype)
      and not a.attisdropped and c.relname not like 'rewards\_%'
  loop
    execute format('select exists (select 1 from %I.%I where %I::text = $1::text)', r.esquema, r.tabla, r.columna)
      into hay using p_user;
    if hay then return false; end if;
  end loop;
  -- Archivos de Storage (owner_id es texto y sin clave foránea).
  if exists (select 1 from storage.objects where owner_id = p_user::text) then
    return false;
  end if;
  return true;
end $$;

revoke execute on function public.rewards_usuario_solo_rewards(uuid) from public, anon, authenticated;
grant execute on function public.rewards_usuario_solo_rewards(uuid) to service_role;
