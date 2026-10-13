import { useState } from "react";
import { useQueryClient } from "@tanstack/react-query";
import { UserPlus } from "lucide-react";
import { funcion, useFamilias, useGuardarPrograma, useProgramas, useUso, type Perfil } from "@/lib/datos";
import { NOMBRE_TIPO_CODIGO, NOMBRE_TIPO_PROGRAMA, TIPOS_CODIGO, TIPOS_PROGRAMA, type Programa } from "@/lib/tipos";
import { fechaHora, numero } from "@/lib/formato";
import { Modal } from "@/components/Modal";

/** Panel de administración: miembros e invitaciones, uso y catálogo. */
export function Admin({ usuario, perfil }: { usuario: string; perfil: Perfil }) {
  const [pestana, setPestana] = useState<"miembros" | "uso" | "catalogo">("miembros");
  return (
    <div className="space-y-5">
      <div className="inline-flex rounded-full bg-black/5 p-1 dark:bg-white/10">
        {(["miembros", "uso", "catalogo"] as const).map((p) => (
          <button key={p} onClick={() => setPestana(p)}
            className={`rounded-full px-4 py-1.5 text-sm font-semibold ${pestana === p ? "bg-panel shadow dark:bg-panel-oscuro" : "opacity-60"}`}>
            {{ miembros: "Miembros", uso: "Uso", catalogo: "Catálogo" }[p]}
          </button>
        ))}
      </div>
      {pestana === "miembros" && <Miembros usuario={usuario} perfil={perfil} />}
      {pestana === "uso" && <PanelUso />}
      {pestana === "catalogo" && <Catalogo />}
    </div>
  );
}

function Miembros({ usuario, perfil }: { usuario: string; perfil: Perfil }) {
  const uso = useUso(true);
  const familias = useFamilias(true);
  const cliente = useQueryClient();
  const [invitando, setInvitando] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const refrescar = () => { void cliente.invalidateQueries({ queryKey: ["uso"] }); void cliente.invalidateQueries({ queryKey: ["miembros"] }); };

  async function accion(cuerpo: Record<string, unknown>, aviso?: string) {
    if (aviso && !confirm(aviso)) return;
    setError(null);
    try { await funcion("rewards-cuenta", cuerpo); refrescar(); }
    catch (e) { const m = (e as Error).message; setError(m === "es_administrador" ? "No se puede cambiar ni quitar a un administrador desde aquí." : m); }
  }

  async function nuevaFamilia() {
    const nombre = prompt("Nombre de la nueva familia (p. ej. «Revisión App Store»):")?.trim();
    if (!nombre) return;
    try { await funcion("rewards-cuenta", { accion: "nueva_familia", nombre }); void cliente.invalidateQueries({ queryKey: ["familias"] }); }
    catch (e) { setError((e as Error).message); }
  }

  return (
    <section className="space-y-3">
      <div className="flex flex-wrap gap-2">
        <button className="boton-principal" onClick={() => setInvitando(true)}><UserPlus size={18} />Invitar</button>
        <button className="boton-secundario" onClick={nuevaFamilia}>Nueva familia</button>
      </div>
      {error && <p className="text-sm text-red-600">{error}</p>}
      <div className="panel overflow-x-auto">
        <table className="w-full text-sm">
          <thead className="text-left text-xs text-black/50 dark:text-white/50">
            <tr><th className="p-3">Nombre</th><th className="p-3">Correo</th><th className="p-3">Familia</th><th className="p-3">Rol</th>
              <th className="p-3 text-right">Tarjetas</th><th className="p-3">Última sincronización</th><th className="p-3" /></tr>
          </thead>
          <tbody className="divide-y divide-black/5 dark:divide-white/10">
            {uso.data?.miembros.map((m) => (
              <tr key={m.user_id}>
                <td className="p-3 font-medium">{m.nombre}</td>
                <td className="p-3">{m.email}</td>
                <td className="p-3">{m.familia}</td>
                <td className="p-3">
                  {m.user_id === usuario ? "Tú" : (
                    <select className="rounded-lg bg-transparent" value={m.rol} onChange={(e) => accion({ accion: "rol", user_id: m.user_id, rol: e.target.value })}>
                      <option value="miembro">Miembro</option><option value="admin">Responsable</option>
                    </select>
                  )}
                </td>
                <td className="p-3 text-right tabular-nums">{m.tarjetas}</td>
                <td className="p-3">{fechaHora(m.ultima_sincronizacion)}</td>
                <td className="p-3 text-right">
                  {m.user_id !== usuario && (
                    <button className="text-red-600" onClick={() => accion({ accion: "quitar", user_id: m.user_id },
                      `¿Quitar a ${m.nombre} de la familia? Dejará de ver las tarjetas compartidas.`)}>Quitar</button>
                  )}
                </td>
              </tr>
            ))}
          </tbody>
        </table>
        {uso.isLoading && <p className="p-3 text-black/50">Cargando…</p>}
      </div>
      {invitando && (
        <Invitar familias={familias.data ?? []} familiaPorDefecto={perfil.miembro?.familia_id}
          onCerrar={() => { setInvitando(false); refrescar(); }} />
      )}
    </section>
  );
}

function Invitar({ familias, familiaPorDefecto, onCerrar }: {
  familias: { id: string; nombre: string }[]; familiaPorDefecto?: string; onCerrar: () => void;
}) {
  const [email, setEmail] = useState("");
  const [nombre, setNombre] = useState("");
  const [familia, setFamilia] = useState(familiaPorDefecto ?? familias[0]?.id ?? "");
  const [pais, setPais] = useState("MX");
  const [rol, setRol] = useState("miembro");
  const [estado, setEstado] = useState<{ ok?: boolean; error?: string; ocupado?: boolean }>({});

  async function enviar() {
    setEstado({ ocupado: true });
    try {
      await funcion("rewards-invitar", { email: email.trim(), nombre: nombre.trim(), familia_id: familia || undefined, pais, rol });
      setEstado({ ok: true });
    } catch (e) {
      const m = (e as Error).message;
      setEstado({ error: m === "otra_familia" ? "Ese correo ya pertenece a otra familia." : m });
      return;
    }
  }

  return (
    <Modal titulo="Invitar a alguien" onCerrar={onCerrar}>
      {estado.ok ? (
        <div className="space-y-4">
          <p>Listo. <strong>{nombre}</strong> ya puede entrar en la app o en esta web con <strong>{email.trim()}</strong>: recibirá un código en su correo al intentarlo.</p>
          <button className="boton-principal w-full" onClick={onCerrar}>Hecho</button>
        </div>
      ) : (
        <form className="space-y-3" onSubmit={(e) => { e.preventDefault(); void enviar(); }}>
          <input className="campo" type="email" placeholder="Correo" required value={email} onChange={(e) => setEmail(e.target.value)} />
          <input className="campo" placeholder="Nombre" required maxLength={40} value={nombre} onChange={(e) => setNombre(e.target.value)} />
          <div className="grid grid-cols-3 gap-2">
            <select className="campo" value={familia} onChange={(e) => setFamilia(e.target.value)} aria-label="Familia">
              {familias.map((f) => <option key={f.id} value={f.id}>{f.nombre}</option>)}
            </select>
            <select className="campo" value={pais} onChange={(e) => setPais(e.target.value)} aria-label="País">
              <option value="MX">México</option><option value="ES">España</option>
            </select>
            <select className="campo" value={rol} onChange={(e) => setRol(e.target.value)} aria-label="Rol">
              <option value="miembro">Miembro</option><option value="admin">Responsable</option>
            </select>
          </div>
          {estado.error && <p className="text-sm text-red-600">{estado.error}</p>}
          <button className="boton-principal w-full" disabled={estado.ocupado || !email.includes("@") || !nombre.trim()}>Invitar</button>
        </form>
      )}
    </Modal>
  );
}

function PanelUso() {
  const uso = useUso(true);
  if (uso.isLoading) return <p className="text-black/50">Cargando…</p>;
  if (uso.error || !uso.data) return <p className="text-red-600">No se pudo cargar el uso.</p>;
  const { totales, por_programa } = uso.data;
  const maximo = Math.max(1, ...por_programa.map((p) => p.tarjetas));
  return (
    <div className="space-y-5">
      <div className="grid grid-cols-2 gap-3 sm:grid-cols-4">
        {([["Familias", totales.familias], ["Miembros", totales.miembros], ["Tarjetas", totales.tarjetas], ["Compartidas", totales.compartidas]] as const).map(([k, v]) => (
          <div key={k} className="panel p-4"><div className="text-3xl font-bold tabular-nums">{numero(v)}</div><div className="text-sm text-black/50 dark:text-white/50">{k}</div></div>
        ))}
      </div>
      <section className="panel p-4">
        <h3 className="mb-3 font-semibold">Tarjetas por programa</h3>
        <ul className="space-y-2">
          {por_programa.map((p) => (
            <li key={p.programa} className="grid grid-cols-[minmax(0,12rem)_1fr_3rem] items-center gap-3 text-sm">
              <span className="truncate">{p.programa}</span>
              <span className="h-2 rounded-full bg-savium" style={{ width: `${(p.tarjetas / maximo) * 100}%` }} />
              <span className="text-right tabular-nums">{p.tarjetas}</span>
            </li>
          ))}
          {por_programa.length === 0 && <li className="text-black/50">Aún no hay tarjetas.</li>}
        </ul>
      </section>
      <p className="text-xs text-black/50 dark:text-white/50">Actualizado {fechaHora(uso.data.generado)}. Solo conteos: el contenido de las tarjetas privadas no es visible para nadie más.</p>
    </div>
  );
}

function Catalogo() {
  const programas = useProgramas();
  const guardar = useGuardarPrograma();
  const [editando, setEditando] = useState<Partial<Programa> | null>(null);
  const [filtro, setFiltro] = useState("");

  return (
    <section className="space-y-3">
      <div className="flex gap-2">
        <input className="campo max-w-xs" placeholder="Buscar" value={filtro} onChange={(e) => setFiltro(e.target.value)} />
        <button className="boton-principal" onClick={() => setEditando({ tipo: "comercio", pais: "MX", color: "#4F8248", unidad: "puntos", codigo_tipo: "code128", activo: true })}>Añadir programa</button>
      </div>
      <div className="panel divide-y divide-black/5 dark:divide-white/10">
        {(programas.data ?? []).filter((p) => p.nombre.toLowerCase().includes(filtro.toLowerCase())).map((p) => (
          <button key={p.id} className={`flex w-full items-center gap-3 px-4 py-2.5 text-left text-sm ${p.activo ? "" : "opacity-40"}`} onClick={() => setEditando(p)}>
            <span className="h-4 w-4 rounded-full" style={{ background: p.color }} />
            <span className="flex-1 font-medium">{p.nombre}</span>
            <span className="text-black/50 dark:text-white/50">{NOMBRE_TIPO_PROGRAMA[p.tipo]} · {p.pais} · {p.unidad} · {NOMBRE_TIPO_CODIGO[p.codigo_tipo]}</span>
          </button>
        ))}
      </div>
      {editando && (
        <Modal titulo={editando.id ? "Editar programa" : "Nuevo programa"} onCerrar={() => setEditando(null)}>
          <form className="space-y-3" onSubmit={async (e) => {
            e.preventDefault();
            await guardar.mutateAsync(editando as Programa);
            setEditando(null);
          }}>
            <input className="campo" placeholder="Nombre" required maxLength={60} value={editando.nombre ?? ""} onChange={(e) => setEditando({ ...editando, nombre: e.target.value })} />
            <div className="grid grid-cols-2 gap-2">
              <select className="campo" value={editando.tipo} onChange={(e) => setEditando({ ...editando, tipo: e.target.value as Programa["tipo"] })}>
                {TIPOS_PROGRAMA.map((t) => <option key={t} value={t}>{NOMBRE_TIPO_PROGRAMA[t]}</option>)}
              </select>
              <select className="campo" value={editando.pais} onChange={(e) => setEditando({ ...editando, pais: e.target.value as Programa["pais"] })}>
                <option value="MX">México</option><option value="ES">España</option><option value="INT">Internacional</option>
              </select>
              <input className="campo" placeholder="Unidad" required maxLength={20} value={editando.unidad ?? ""} onChange={(e) => setEditando({ ...editando, unidad: e.target.value })} />
              <select className="campo" value={editando.codigo_tipo} onChange={(e) => setEditando({ ...editando, codigo_tipo: e.target.value as Programa["codigo_tipo"] })}>
                {TIPOS_CODIGO.map((c) => <option key={c} value={c}>{NOMBRE_TIPO_CODIGO[c]}</option>)}
              </select>
              <label className="flex items-center gap-2"><input type="color" value={editando.color ?? "#4F8248"} onChange={(e) => setEditando({ ...editando, color: e.target.value.toUpperCase() })} />Color</label>
              <label className="flex items-center gap-2"><input type="checkbox" checked={editando.activo ?? true} onChange={(e) => setEditando({ ...editando, activo: e.target.checked })} />Activo</label>
            </div>
            {guardar.error && <p className="text-sm text-red-600">{guardar.error.message}</p>}
            <button className="boton-principal w-full" disabled={guardar.isPending}>Guardar</button>
          </form>
        </Modal>
      )}
    </section>
  );
}
