// Invita a una persona a una familia de Rewards (solo administradores).
// El registro público está desactivado: esta función crea el usuario de Auth (si no existe) y su fila de
// miembro. La persona entra después con su correo y un código de un solo uso.
import { esAdmin, json, llamante, preflight, servicio, texto, uuid } from "../_comun/comun.ts";

Deno.serve(async (req) => {
  const pre = preflight(req);
  if (pre) return pre;
  if (req.method !== "POST") return json({ error: "metodo" }, 405);

  const yo = await llamante(req);
  if (!yo) return json({ error: "sin_sesion" }, 401);
  if (!(await esAdmin(yo.id))) return json({ error: "no_autorizado" }, 403);

  const cuerpo = await req.json().catch(() => null) as Record<string, unknown> | null;
  const email = typeof cuerpo?.email === "string" ? cuerpo.email.trim().toLowerCase() : "";
  const nombre = cuerpo?.nombre;
  const rol = cuerpo?.rol === "admin" ? "admin" : "miembro";
  const pais = cuerpo?.pais === "ES" ? "ES" : "MX";
  if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email) || email.length > 254) return json({ error: "email" }, 400);
  if (!texto(nombre, 1, 40)) return json({ error: "nombre" }, 400);

  // Familia: la indicada, o la del administrador.
  let familiaId = cuerpo?.familia_id;
  if (familiaId !== undefined && !uuid(familiaId)) return json({ error: "familia" }, 400);
  if (!familiaId) {
    const { data } = await servicio.from("rewards_miembros").select("familia_id").eq("user_id", yo.id).maybeSingle();
    familiaId = data?.familia_id;
  }
  if (!familiaId) return json({ error: "sin_familia" }, 400);
  const { data: familia } = await servicio.from("rewards_familias").select("id").eq("id", familiaId).maybeSingle();
  if (!familia) return json({ error: "familia" }, 404);

  // Usuario: crearlo o reutilizar el existente.
  let userId: string | undefined;
  const creado = await servicio.auth.admin.createUser({ email, email_confirm: true });
  if (creado.data.user) {
    userId = creado.data.user.id;
  } else {
    for (let pagina = 1; !userId && pagina <= 20; pagina++) {
      const { data, error } = await servicio.auth.admin.listUsers({ page: pagina, perPage: 200 });
      if (error) return json({ error: error.message }, 500);
      userId = data.users.find((u) => u.email?.toLowerCase() === email)?.id;
      if (data.users.length < 200) break;
    }
    if (!userId) return json({ error: creado.error?.message ?? "crear_usuario" }, 500);
  }

  const { data: existente } = await servicio.from("rewards_miembros").select("familia_id").eq("user_id", userId).maybeSingle();
  if (existente && existente.familia_id !== familiaId) return json({ error: "otra_familia" }, 409);
  // Reinvitar a alguien que ya es de la familia no cambia nada (ni su nombre ni su rol).
  if (existente) return json({ user_id: userId, ya_era_miembro: true });

  // `rol` es solo una etiqueta dentro de la familia: el panel de administración lo da rewards_admins,
  // que se rellena a mano por SQL y nunca desde aquí.
  const { error } = await servicio.from("rewards_miembros")
    .insert({ user_id: userId, familia_id: familiaId, nombre: (nombre as string).trim(), rol, pais });
  if (error) return json({ error: error.message }, 500);

  return json({ user_id: userId });
});
