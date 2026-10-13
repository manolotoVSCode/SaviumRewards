-- Pruebas de reglas de acceso de Rewards.
-- Se ejecutan dentro de una transacción que se deshace al final, con la migración aplicada antes en la
-- misma transacción:  begin; <migración>; <este archivo>; rollback;
-- Si alguna comprobación falla, lanza una excepción con el motivo.

-- Usuarios de prueba: Ana y Beto (familia 1), Carla (familia 2), Admin (familia 1, administrador).
insert into auth.users (id, email, aud, role) values
  ('00000000-0000-4000-a000-00000000000a', 'ana@prueba.test', 'authenticated', 'authenticated'),
  ('00000000-0000-4000-a000-00000000000b', 'beto@prueba.test', 'authenticated', 'authenticated'),
  ('00000000-0000-4000-a000-00000000000c', 'carla@prueba.test', 'authenticated', 'authenticated'),
  ('00000000-0000-4000-a000-0000000000ad', 'admin@prueba.test', 'authenticated', 'authenticated');

insert into public.rewards_familias (id, nombre) values
  ('00000000-0000-4000-b000-000000000001', 'Familia 1'),
  ('00000000-0000-4000-b000-000000000002', 'Familia 2');

insert into public.rewards_miembros (user_id, familia_id, nombre, rol) values
  ('00000000-0000-4000-a000-00000000000a', '00000000-0000-4000-b000-000000000001', 'Ana', 'miembro'),
  ('00000000-0000-4000-a000-00000000000b', '00000000-0000-4000-b000-000000000001', 'Beto', 'miembro'),
  ('00000000-0000-4000-a000-00000000000c', '00000000-0000-4000-b000-000000000002', 'Carla', 'miembro'),
  ('00000000-0000-4000-a000-0000000000ad', '00000000-0000-4000-b000-000000000001', 'Admin', 'admin');
insert into public.rewards_admins (user_id) values ('00000000-0000-4000-a000-0000000000ad');

insert into public.rewards_tarjetas (id, user_id, nombre, codigo_tipo, codigo_valor, compartida, actualizado) values
  ('00000000-0000-4000-c000-0000000000a1', '00000000-0000-4000-a000-00000000000a', 'Ana privada', 'qr', 'A1', false, now()),
  ('00000000-0000-4000-c000-0000000000a2', '00000000-0000-4000-a000-00000000000a', 'Ana compartida', 'qr', 'A2', true, now()),
  ('00000000-0000-4000-c000-0000000000b1', '00000000-0000-4000-a000-00000000000b', 'Beto privada', 'ninguno', null, false, now()),
  ('00000000-0000-4000-c000-0000000000c1', '00000000-0000-4000-a000-00000000000c', 'Carla compartida', 'ninguno', null, true, now());

-- Como Beto
set local role authenticated;
set local request.jwt.claims = '{"sub":"00000000-0000-4000-a000-00000000000b","role":"authenticated"}';

do $$
declare n int; ids text;
begin
  select string_agg(nombre, ',' order by nombre) into ids from public.rewards_tarjetas;
  if ids is distinct from 'Ana compartida,Beto privada' then
    raise exception 'Beto debería ver «Ana compartida,Beto privada», ve: %', ids;
  end if;

  update public.rewards_tarjetas set saldo = 1 where id = '00000000-0000-4000-c000-0000000000a2';
  get diagnostics n = row_count;
  if n <> 0 then raise exception 'Beto pudo editar la tarjeta compartida de Ana'; end if;

  begin
    update public.rewards_tarjetas set user_id = '00000000-0000-4000-a000-00000000000a'
      where id = '00000000-0000-4000-c000-0000000000b1';
    raise exception 'Beto pudo regalar su tarjeta a Ana';
  exception when insufficient_privilege then null;
  end;

  begin
    insert into public.rewards_tarjetas (id, user_id, nombre, actualizado)
      values (gen_random_uuid(), '00000000-0000-4000-a000-00000000000a', 'Suplantada', now());
    raise exception 'Beto pudo crear una tarjeta a nombre de Ana';
  exception when insufficient_privilege then null;
  end;

  -- Upsert sobre el id de una tarjeta ajena: no debe pisarla.
  begin
    insert into public.rewards_tarjetas (id, nombre, actualizado)
      values ('00000000-0000-4000-c000-0000000000a1', 'Pisada', now())
      on conflict (id) do update set nombre = excluded.nombre;
    raise exception 'Beto pudo pisar la tarjeta privada de Ana con un upsert';
  exception when insufficient_privilege then null;
  end;

  -- Crear la suya sí puede (user_id por defecto).
  insert into public.rewards_tarjetas (id, nombre, actualizado) values (gen_random_uuid(), 'Beto nueva', now());

  begin
    insert into public.rewards_programas (nombre, tipo, pais, color, unidad) values ('X', 'hotel', 'MX', '#000000', 'pts');
    raise exception 'Beto pudo añadir un programa al catálogo';
  exception when insufficient_privilege then null;
  end;

  begin
    update public.rewards_miembros set rol = 'admin' where user_id = '00000000-0000-4000-a000-00000000000b';
    raise exception 'Beto pudo hacerse administrador';
  exception when insufficient_privilege then null;
  end;

  update public.rewards_miembros set nombre = 'Otro' where user_id = '00000000-0000-4000-a000-00000000000a';
  get diagnostics n = row_count;
  if n <> 0 then raise exception 'Beto pudo renombrar a Ana'; end if;

  select count(*) into n from public.rewards_miembros;
  if n <> 3 then raise exception 'Beto debería ver 3 miembros de su familia, ve %', n; end if;

  select count(*) into n from public.rewards_admins;
  if n <> 0 then raise exception 'Beto ve la lista de administradores'; end if;

  begin
    perform public.rewards_uso();
    raise exception 'Beto pudo ver el panel de uso';
  exception when insufficient_privilege then null;
  end;

  -- Finanzas: sin filas ajenas.
  select count(*) into n from public.transacciones;
  if n <> 0 then raise exception 'Beto ve % transacciones de Finanzas', n; end if;
  select count(*) into n from public.cuentas;
  if n <> 0 then raise exception 'Beto ve % cuentas de Finanzas', n; end if;
end $$;

-- Gana la última edición: una escritura con `actualizado` anterior no cambia los datos, pero sí `sincronizado`.
do $$
declare v text; antes timestamptz; despues timestamptz;
begin
  update public.rewards_tarjetas set nombre = 'Beto reciente', actualizado = now() + interval '1 hour'
    where id = '00000000-0000-4000-c000-0000000000b1';
  select sincronizado into antes from public.rewards_tarjetas where id = '00000000-0000-4000-c000-0000000000b1';
  insert into public.rewards_tarjetas (id, nombre, actualizado) values ('00000000-0000-4000-c000-0000000000b1', 'Beto viejo', now())
    on conflict (id) do update set nombre = excluded.nombre, actualizado = excluded.actualizado;
  select nombre, sincronizado into v, despues from public.rewards_tarjetas where id = '00000000-0000-4000-c000-0000000000b1';
  if v <> 'Beto reciente' then raise exception 'Una edición antigua pisó a una más reciente: %', v; end if;
  if despues <= antes then raise exception 'La escritura descartada no movió sincronizado'; end if;
end $$;

-- Como Carla (otra familia): no ve nada de la familia 1.
set local request.jwt.claims = '{"sub":"00000000-0000-4000-a000-00000000000c","role":"authenticated"}';
do $$
declare ids text;
begin
  select string_agg(nombre, ',' order by nombre) into ids from public.rewards_tarjetas;
  if ids is distinct from 'Carla compartida' then raise exception 'Carla ve: %', ids; end if;
end $$;

-- Como Ana: al hacer privada su compartida, Beto deja de verla.
set local request.jwt.claims = '{"sub":"00000000-0000-4000-a000-00000000000a","role":"authenticated"}';
update public.rewards_tarjetas set compartida = false where id = '00000000-0000-4000-c000-0000000000a2';
set local request.jwt.claims = '{"sub":"00000000-0000-4000-a000-00000000000b","role":"authenticated"}';
do $$
declare n int;
begin
  select count(*) into n from public.rewards_tarjetas where user_id = '00000000-0000-4000-a000-00000000000a';
  if n <> 0 then raise exception 'Beto sigue viendo tarjetas de Ana tras hacerlas privadas'; end if;
end $$;

-- Como Admin: panel de uso y catálogo sí; privadas ajenas no.
set local request.jwt.claims = '{"sub":"00000000-0000-4000-a000-0000000000ad","role":"authenticated"}';
do $$
declare n int; uso jsonb;
begin
  uso := public.rewards_uso();
  if (uso->'totales'->>'miembros')::int <> 4 then raise exception 'Uso: miembros = %', uso->'totales'->>'miembros'; end if;
  insert into public.rewards_programas (nombre, tipo, pais, color, unidad) values ('Prueba', 'hotel', 'MX', '#112233', 'puntos');
  select count(*) into n from public.rewards_tarjetas where nombre like '%privada%';
  if n <> 0 then raise exception 'El administrador ve tarjetas privadas ajenas'; end if;
end $$;

-- anon: sin acceso.
reset role;
set local role anon;
do $$
begin
  begin
    perform 1 from public.rewards_tarjetas;
    raise exception 'anon puede leer rewards_tarjetas';
  exception when insufficient_privilege then null;
  end;
end $$;
reset role;

select 'rewards_rls: todo correcto' as resultado;
