import { HashRouter, NavLink, Navigate, Route, Routes } from "react-router-dom";
import { LogOut } from "lucide-react";
import { supabase } from "@/lib/supabase";
import { useSesion } from "@/lib/sesion";
import { usePerfil } from "@/lib/datos";
import { Entrar } from "@/pages/Entrar";
import { Tarjetas } from "@/pages/Tarjetas";
import { Admin } from "@/pages/Admin";
import { Privacidad } from "@/pages/Privacidad";

export default function App() {
  return (
    <HashRouter>
      <Routes>
        <Route path="/privacidad" element={<Privacidad />} />
        <Route path="/*" element={<Protegida />} />
      </Routes>
    </HashRouter>
  );
}

function Protegida() {
  const sesion = useSesion();
  if (sesion === undefined) return null;
  if (!sesion) return <Entrar />;
  return <Panel usuario={sesion.user.id} email={sesion.user.email ?? ""} />;
}

function Panel({ usuario, email }: { usuario: string; email: string }) {
  const perfil = usePerfil(usuario);
  if (perfil.isLoading) return null;
  if (perfil.error) return <p className="p-8 text-red-600">No se pudo cargar tu perfil: {perfil.error.message}</p>;
  const p = perfil.data!;

  return (
    <div className="mx-auto max-w-6xl px-4 pb-16 pt-6 sm:px-6">
      <header className="mb-6 flex flex-wrap items-center gap-4">
        <img src="favicon.svg" alt="" className="h-10 w-10" />
        <div className="mr-auto">
          <h1 className="text-2xl font-bold leading-tight">Savium Rewards</h1>
          <p className="text-sm text-black/50 dark:text-white/50">{p.familia ?? email}</p>
        </div>
        <nav className="flex gap-1">
          <NavLink to="/" end className={({ isActive }) => `boton ${isActive ? "bg-black/10 dark:bg-white/15" : ""}`}>Tarjetas</NavLink>
          {p.admin && <NavLink to="/admin" className={({ isActive }) => `boton ${isActive ? "bg-black/10 dark:bg-white/15" : ""}`}>Administración</NavLink>}
        </nav>
        <button className="boton-secundario" onClick={() => supabase.auth.signOut({ scope: "local" })} title={email}><LogOut size={16} />Salir</button>
      </header>
      {!p.miembro && !p.admin ? (
        <div className="panel p-10 text-center">
          <p className="text-lg font-semibold">Sin familia</p>
          <p className="text-black/50 dark:text-white/50">Tu cuenta no pertenece a ninguna familia de Savium Rewards. Pide a quien la administra que te invite.</p>
        </div>
      ) : (
        <Routes>
          <Route path="/" element={p.miembro ? <Tarjetas usuario={usuario} perfil={p} /> : <Navigate to="/admin" replace />} />
          {p.admin && <Route path="/admin" element={<Admin usuario={usuario} perfil={p} />} />}
          <Route path="*" element={<Navigate to="/" replace />} />
        </Routes>
      )}
    </div>
  );
}
