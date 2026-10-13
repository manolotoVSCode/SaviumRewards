// Gestión de cuentas de Rewards.
//   { accion: "eliminar" }                       — el propio usuario borra su cuenta (lo exige la App Store).
//   { accion: "quitar", user_id }                — un administrador quita a alguien de su familia.
//   { accion: "rol", user_id, rol }              — un administrador cambia el rol (etiqueta) de un miembro.
// Ninguna acción toca rewards_admins (se gestiona a mano por SQL) ni puede aplicarse a un administrador.
//   { accion: "nueva_familia", nombre }          — un administrador crea una familia (p. ej. la de revisión de Apple).
// El proyecto es compartido con Savium Finanzas: el usuario de Auth solo se borra si no tiene datos fuera de
// Rewards (rewards_usuario_solo_rewards); si los tiene, se borran sus datos de Rewards y la cuenta se conserva.
import { esAdmin, json, llamante, preflight, servicio, texto, uuid } from "../_comun/comun.ts";

/** Borra todo lo de Rewards del usuario. Devuelve el primer error, si lo hay. */
async function borrarDatosRewards(userId: string): Promise<string | null> {
  for (const tabla of ["rewards_tarjetas", "rewards_miembros", "rewards_admins"]) {
    const { error } = await servicio.from(tabla).delete().eq("user_id", userId);
    if (error) return error.message;
  }
  return null;
}

Deno.serve(async (req) => {
  const pre = preflight(req);
  if (pre) return pre;
  if (req.method !== "POST") return json({ error: "metodo" }, 405);

  const yo = await llamante(req);
  if (!yo) return json({ error: "sin_sesion" }, 401);
  const cuerpo = await req.json().catch(() => null) as Record<string, unknown> | null;

  switch (cuerpo?.accion) {
    case "eliminar": {
      const { data: solo, error } = await servicio.rpc("rewards_usuario_solo_rewards", { p_user: yo.id });
      if (error) return json({ error: error.message }, 500);
      const fallo = await borrarDatosRewards(yo.id);
      if (fallo) return json({ error: fallo }, 500);
      if (solo === true) {
        const borrado = await servicio.auth.admin.deleteUser(yo.id);
        if (borrado.error) return json({ error: borrado.error.message }, 500);
      }
      return json({ ok: true, usuario_borrado: solo === true });
    }

    case "quitar": {
      if (!(await esAdmin(yo.id))) return json({ error: "no_autorizado" }, 403);
      if (!uuid(cuerpo.user_id) || cuerpo.user_id === yo.id) return json({ error: "user_id" }, 400);
      if (await esAdmin(cuerpo.user_id as string, true)) return json({ error: "es_administrador" }, 403);
      // Primero sale de la familia (lo importante); después sus tarjetas dejan de estar compartidas,
      // para que si un día entra en otra familia no aparezcan allí.
      const { error } = await servicio.from("rewards_miembros").delete().eq("user_id", cuerpo.user_id);
      if (error) return json({ error: error.message }, 500);
      const privadas = await servicio.from("rewards_tarjetas").update({ compartida: false, actualizado: new Date().toISOString() })
        .eq("user_id", cuerpo.user_id).eq("compartida", true);
      if (privadas.error) return json({ error: privadas.error.message }, 500);
      // Sus sesiones siguen abiertas, pero las reglas de acceso ya no le dejan ver la familia, y la app
      // borra su copia local de las tarjetas de la familia en la siguiente sincronización.
      return json({ ok: true });
    }

    case "rol": {
      if (!(await esAdmin(yo.id))) return json({ error: "no_autorizado" }, 403);
      if (!uuid(cuerpo.user_id) || cuerpo.user_id === yo.id) return json({ error: "user_id" }, 400);
      if (await esAdmin(cuerpo.user_id as string, true)) return json({ error: "es_administrador" }, 403);
      const rol = cuerpo.rol === "admin" ? "admin" : "miembro";
      const { error } = await servicio.from("rewards_miembros").update({ rol }).eq("user_id", cuerpo.user_id);
      if (error) return json({ error: error.message }, 500);
      return json({ ok: true });
    }

    case "nueva_familia": {
      if (!(await esAdmin(yo.id))) return json({ error: "no_autorizado" }, 403);
      if (!texto(cuerpo.nombre, 1, 60)) return json({ error: "nombre" }, 400);
      const { data, error } = await servicio.from("rewards_familias")
        .insert({ nombre: (cuerpo.nombre as string).trim() }).select("id").single();
      if (error) return json({ error: error.message }, 500);
      return json({ familia_id: data.id });
    }

    default:
      return json({ error: "accion" }, 400);
  }
});
