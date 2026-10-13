-- Arranque: crea la familia del titular y lo hace administrador. Ejecutar una sola vez en el SQL Editor,
-- después de la migración. El uid es el del titular de Savium Finanzas (el mismo que usa share_panel).
with f as (insert into public.rewards_familias (nombre) values ('Familia de la Torre') returning id)
insert into public.rewards_miembros (user_id, familia_id, nombre, rol, pais)
select '01ad1bcc-00e7-47a7-88b6-8b2fc8afa52e', id, 'Manuel', 'admin', 'MX' from f;
insert into public.rewards_admins (user_id) values ('01ad1bcc-00e7-47a7-88b6-8b2fc8afa52e');
