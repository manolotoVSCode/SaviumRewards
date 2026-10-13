// Consultas a Supabase. Las reglas de acceso limitan todo al usuario y a su familia.
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { supabase } from "./supabase";
import type { Miembro, Programa, Tarjeta } from "./tipos";

export interface Perfil { miembro: Miembro | null; familia: string | null; admin: boolean }

export function usePerfil(usuario: string) {
  return useQuery({
    queryKey: ["perfil", usuario],
    queryFn: async (): Promise<Perfil> => {
      const { data: miembro, error } = await supabase.from("rewards_miembros")
        .select("user_id, familia_id, nombre, rol, pais").eq("user_id", usuario).maybeSingle();
      if (error) throw error;
      const { data: admin } = await supabase.from("rewards_admins").select("user_id").eq("user_id", usuario).maybeSingle();
      let familia: string | null = null;
      if (miembro) {
        const { data } = await supabase.from("rewards_familias").select("nombre").eq("id", miembro.familia_id).maybeSingle();
        familia = data?.nombre ?? null;
      }
      return { miembro: miembro as Miembro | null, familia, admin: !!admin };
    },
  });
}

export function useProgramas() {
  return useQuery({
    queryKey: ["programas"],
    queryFn: async () => {
      const { data, error } = await supabase.from("rewards_programas").select("*").order("nombre");
      if (error) throw error;
      return data as Programa[];
    },
    staleTime: 5 * 60_000,
  });
}

export function useMiembros(familia?: string) {
  return useQuery({
    queryKey: ["miembros", familia],
    enabled: !!familia,
    queryFn: async () => {
      const { data, error } = await supabase.from("rewards_miembros").select("user_id, familia_id, nombre, rol, pais")
        .eq("familia_id", familia!).order("nombre");
      if (error) throw error;
      return data as Miembro[];
    },
  });
}

/** Mis tarjetas y las compartidas de mi familia (las borradas no se muestran). */
export function useTarjetas() {
  return useQuery({
    queryKey: ["tarjetas"],
    queryFn: async () => {
      const { data, error } = await supabase.from("rewards_tarjetas").select("*").eq("borrado", false)
        .order("orden").order("nombre");
      if (error) throw error;
      return data as Tarjeta[];
    },
  });
}

export function useGuardarTarjeta() {
  const cliente = useQueryClient();
  return useMutation({
    mutationFn: async (t: Tarjeta) => {
      // `sincronizado` lo pone el servidor.
      const fila: Tarjeta = { ...t, actualizado: new Date().toISOString() };
      delete fila.sincronizado;
      const { error } = await supabase.from("rewards_tarjetas").upsert(fila, { onConflict: "id" });
      if (error) throw error;
    },
    onSuccess: () => cliente.invalidateQueries({ queryKey: ["tarjetas"] }),
  });
}

// MARK: Administración

export interface Uso {
  generado: string;
  totales: { familias: number; miembros: number; tarjetas: number; compartidas: number };
  miembros: {
    user_id: string; nombre: string; email: string; rol: string; pais: string; familia_id: string; familia: string;
    ultima_sincronizacion: string | null; ultimo_acceso: string | null; tarjetas: number;
  }[];
  por_programa: { programa: string; tarjetas: number }[];
}

export function useUso(activo: boolean) {
  return useQuery({
    queryKey: ["uso"],
    enabled: activo,
    queryFn: async () => {
      const { data, error } = await supabase.rpc("rewards_uso");
      if (error) throw error;
      return data as Uso;
    },
  });
}

export function useFamilias(activo: boolean) {
  return useQuery({
    queryKey: ["familias"],
    enabled: activo,
    queryFn: async () => {
      const { data, error } = await supabase.from("rewards_familias").select("id, nombre").order("nombre");
      if (error) throw error;
      return data as { id: string; nombre: string }[];
    },
  });
}

/** Llama a una Edge Function y devuelve su JSON; lanza un Error con el mensaje del servidor si falla. */
export async function funcion<T>(nombre: string, cuerpo: Record<string, unknown>): Promise<T> {
  const { data, error } = await supabase.functions.invoke(nombre, { body: cuerpo });
  if (error) {
    let detalle = error.message;
    try { detalle = (await (error as { context?: Response }).context?.json())?.error ?? detalle; } catch { /* sin cuerpo */ }
    throw new Error(detalle);
  }
  return data as T;
}

export function useGuardarPrograma() {
  const cliente = useQueryClient();
  return useMutation({
    mutationFn: async (p: Partial<Programa> & { nombre: string }) => {
      const { error } = p.id
        ? await supabase.from("rewards_programas").update(p).eq("id", p.id)
        : await supabase.from("rewards_programas").insert(p);
      if (error) throw error;
    },
    onSuccess: () => cliente.invalidateQueries({ queryKey: ["programas"] }),
  });
}
