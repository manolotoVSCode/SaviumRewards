// Utilidades compartidas por las funciones de Rewards.
import { createClient, type SupabaseClient, type User } from "jsr:@supabase/supabase-js@2";

export const servicio: SupabaseClient = createClient(
  Deno.env.get("SUPABASE_URL")!,
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  { auth: { persistSession: false } },
);

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

export const json = (cuerpo: unknown, status = 200) =>
  new Response(JSON.stringify(cuerpo), { status, headers: { ...cors, "Content-Type": "application/json" } });

export const preflight = (req: Request) => (req.method === "OPTIONS" ? new Response("ok", { headers: cors }) : null);

/** Usuario que llama, a partir de su JWT. */
export async function llamante(req: Request): Promise<User | null> {
  const token = (req.headers.get("Authorization") ?? "").replace(/^Bearer\s+/i, "");
  if (!token) return null;
  const { data, error } = await servicio.auth.getUser(token);
  return error ? null : data.user;
}

/** ¿Es administrador? Si la consulta falla, devuelve `siFalla` (true para proteger a un posible administrador). */
export async function esAdmin(userId: string, siFalla = false): Promise<boolean> {
  const { data, error } = await servicio.from("rewards_admins").select("user_id").eq("user_id", userId).maybeSingle();
  return error ? siFalla : !!data;
}

export const uuid = (v: unknown): v is string =>
  typeof v === "string" && /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(v);

export const texto = (v: unknown, min: number, max: number): v is string =>
  typeof v === "string" && v.trim().length >= min && v.trim().length <= max;
