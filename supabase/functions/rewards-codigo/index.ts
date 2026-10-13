// Envía el código de acceso SOLO a miembros de una familia de Rewards (solo por invitación).
// La app llama aquí en vez de a Auth directamente. Responde siempre lo mismo, exista o no el correo,
// para no revelar quién está invitado. (Además, el registro público está desactivado en Auth.)
import { createClient } from "jsr:@supabase/supabase-js@2";
import { json, preflight, servicio } from "../_comun/comun.ts";

const publico = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_ANON_KEY")!, {
  auth: { persistSession: false },
});

async function esMiembro(email: string): Promise<boolean> {
  for (let pagina = 1; pagina <= 20; pagina++) {
    const { data, error } = await servicio.auth.admin.listUsers({ page: pagina, perPage: 200 });
    if (error) return false;
    const usuario = data.users.find((u) => u.email?.toLowerCase() === email);
    if (usuario) {
      const { data: miembro } = await servicio.from("rewards_miembros").select("user_id").eq("user_id", usuario.id).maybeSingle();
      return !!miembro;
    }
    if (data.users.length < 200) return false;
  }
  return false;
}

Deno.serve(async (req) => {
  const pre = preflight(req);
  if (pre) return pre;
  if (req.method !== "POST") return json({ error: "metodo" }, 405);

  const cuerpo = await req.json().catch(() => null) as Record<string, unknown> | null;
  const email = typeof cuerpo?.email === "string" ? cuerpo.email.trim().toLowerCase() : "";
  if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email) || email.length > 254) return json({ error: "email" }, 400);

  if (await esMiembro(email)) {
    const { error } = await publico.auth.signInWithOtp({ email, options: { shouldCreateUser: false } });
    if (error && error.status === 429) return json({ error: "demasiados" }, 429);
    if (error) console.error("OTP", error.message);
  }
  return json({ ok: true });
});
