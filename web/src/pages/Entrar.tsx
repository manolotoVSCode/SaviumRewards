import { useState } from "react";
import { supabase } from "@/lib/supabase";
import { FraseSavium } from "@/components/FraseSavium";

/** Entrada con correo y código de 6 dígitos. El registro está cerrado: solo correos invitados. */
export function Entrar() {
  const [email, setEmail] = useState("");
  const [codigo, setCodigo] = useState("");
  const [enviado, setEnviado] = useState(false);
  const [ocupado, setOcupado] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const limpio = email.trim().toLowerCase();

  async function pedir() {
    setOcupado(true); setError(null);
    const { error } = await supabase.auth.signInWithOtp({ email: limpio, options: { shouldCreateUser: false } });
    setOcupado(false);
    if (!error) return setEnviado(true);
    const texto = `${error.message} ${error.code ?? ""}`.toLowerCase();
    setError(texto.includes("signup") || texto.includes("not allowed") || texto.includes("otp_disabled")
      ? "Savium Rewards es solo por invitación. Pide a quien administra tu familia que te invite con este correo."
      : texto.includes("rate") ? "Has pedido varios códigos seguidos. Espera un minuto." : "No se pudo enviar el código.");
  }

  async function verificar() {
    setOcupado(true); setError(null);
    const { error } = await supabase.auth.verifyOtp({ email: limpio, token: codigo.replace(/\D/g, ""), type: "email" });
    setOcupado(false);
    if (error) { setError("El código no es correcto o ha caducado."); setCodigo(""); }
  }

  return (
    <main className="mx-auto flex min-h-screen max-w-sm flex-col items-center justify-center gap-6 px-6 py-12">
      <img src="favicon.svg" alt="" className="h-24 w-24" />
      <div className="text-center">
        <h1 className="text-3xl font-bold">Savium Rewards</h1>
        <p className="mt-1 text-black/50 dark:text-white/50"><FraseSavium /></p>
      </div>
      <form className="w-full space-y-3" onSubmit={(e) => { e.preventDefault(); void (enviado ? verificar() : pedir()); }}>
        <input className="campo" type="email" autoComplete="email" placeholder="Correo electrónico" disabled={enviado}
          value={email} onChange={(e) => setEmail(e.target.value)} autoFocus />
        {enviado && (
          <>
            <input className="campo text-center font-mono text-xl tracking-widest" inputMode="numeric" autoComplete="one-time-code"
              placeholder="000000" maxLength={6} value={codigo} onChange={(e) => setCodigo(e.target.value)} autoFocus />
            <p className="text-center text-xs text-black/50 dark:text-white/50">Te hemos enviado un código a {limpio}.</p>
          </>
        )}
        {error && <p className="text-center text-sm text-red-600">{error}</p>}
        <button className="boton-principal w-full py-3" disabled={ocupado || (enviado ? codigo.replace(/\D/g, "").length < 6 : !limpio.includes("@"))}>
          {enviado ? "Entrar" : "Enviarme un código"}
        </button>
        {enviado && <button type="button" className="w-full text-sm text-savium" onClick={() => { setEnviado(false); setCodigo(""); setError(null); }}>Usar otro correo</button>}
      </form>
      <p className="text-center text-xs text-black/50 dark:text-white/50">Solo por invitación. <a className="underline" href="#/privacidad">Privacidad</a></p>
    </main>
  );
}
