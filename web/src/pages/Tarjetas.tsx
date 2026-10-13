import { useMemo, useState } from "react";
import { Plus, Search } from "lucide-react";
import { useMiembros, useProgramas, useTarjetas, type Perfil } from "@/lib/datos";
import { porUnidad } from "@/lib/totales";
import { titulo, type Tarjeta } from "@/lib/tipos";
import { numero } from "@/lib/formato";
import { TarjetaWeb } from "@/components/TarjetaWeb";
import { Detalle } from "@/components/Detalle";
import { Editor } from "@/components/Editor";

export function Tarjetas({ usuario, perfil }: { usuario: string; perfil: Perfil }) {
  const tarjetas = useTarjetas();
  const programas = useProgramas();
  const miembros = useMiembros(perfil.miembro?.familia_id);
  const [busqueda, setBusqueda] = useState("");
  const [abierta, setAbierta] = useState<Tarjeta | null>(null);
  const [editando, setEditando] = useState<{ t: Tarjeta; nueva: boolean } | null>(null);

  const mapa = useMemo(() => new Map((programas.data ?? []).map((p) => [p.id, p])), [programas.data]);
  const dueno = (t: Tarjeta) => (t.user_id === usuario ? undefined : miembros.data?.find((m) => m.user_id === t.user_id)?.nombre);
  const todas = tarjetas.data ?? [];
  const filtro = (t: Tarjeta) => !busqueda.trim() || [titulo(t, mapa.get(t.programa_id ?? "")), t.numero_socio ?? "", t.titular ?? "", dueno(t) ?? ""]
    .some((s) => s.toLowerCase().includes(busqueda.trim().toLowerCase()));
  const mias = todas.filter((t) => t.user_id === usuario);
  const familia = todas.filter((t) => t.user_id !== usuario);
  const totales = porUnidad(mias, mapa);

  function nueva() {
    const orden = Math.max(-1, ...mias.map((t) => t.orden)) + 1;
    setEditando({ nueva: true, t: {
      id: crypto.randomUUID(), user_id: usuario, programa_id: null, nombre: null, color: null, unidad: null,
      numero_socio: null, codigo_valor: null, codigo_tipo: "ninguno", titular: null, saldo: null, saldo_fecha: null,
      caducidad: null, notas: null, compartida: false, orden, actualizado: new Date().toISOString(), borrado: false,
    } });
  }

  const rejilla = (lista: Tarjeta[]) => (
    <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
      {lista.filter(filtro).map((t) => (
        <TarjetaWeb key={t.id} tarjeta={t} programa={mapa.get(t.programa_id ?? "")} dueno={dueno(t)} onClick={() => setAbierta(t)} />
      ))}
    </div>
  );

  return (
    <div className="space-y-6">
      <div className="flex flex-wrap items-center gap-3">
        {totales.map((t) => (
          <div key={t.unidad} className="panel px-4 py-3">
            <div className="text-2xl font-bold tabular-nums">{numero(t.total)}</div>
            <div className="text-xs font-semibold text-black/50 dark:text-white/50">{t.unidad}</div>
          </div>
        ))}
        <div className="ml-auto flex w-full gap-2 sm:w-auto">
          <label className="relative flex-1 sm:w-64">
            <Search size={16} className="absolute left-3 top-3 opacity-40" />
            <input className="campo pl-9" placeholder="Buscar tarjeta" value={busqueda} onChange={(e) => setBusqueda(e.target.value)} />
          </label>
          <button className="boton-principal" onClick={nueva}><Plus size={18} />Añadir</button>
        </div>
      </div>

      {tarjetas.isLoading && <p className="text-black/50">Cargando…</p>}
      {tarjetas.error && <p className="text-red-600">No se pudieron cargar las tarjetas: {tarjetas.error.message}</p>}
      {mias.length > 0 && <section><h2 className="mb-3 text-xl font-bold">Mías</h2>{rejilla(mias)}</section>}
      {familia.length > 0 && <section><h2 className="mb-3 text-xl font-bold">De la familia</h2>{rejilla(familia)}</section>}
      {!tarjetas.isLoading && todas.length === 0 && (
        <div className="panel p-10 text-center">
          <p className="text-lg font-semibold">Tu cartera está vacía</p>
          <p className="text-black/50 dark:text-white/50">Añade tus tarjetas de puntos, millas y monederos.</p>
        </div>
      )}

      {abierta && (
        <Detalle tarjeta={abierta} programa={mapa.get(abierta.programa_id ?? "")} dueno={dueno(abierta)} onCerrar={() => setAbierta(null)}
          onEditar={abierta.user_id === usuario ? () => { setEditando({ t: abierta, nueva: false }); setAbierta(null); } : undefined} />
      )}
      {editando && (
        <Editor inicial={editando.t} nueva={editando.nueva} programas={programas.data ?? []} pais={perfil.miembro?.pais ?? "MX"}
          onCerrar={() => setEditando(null)} />
      )}
    </div>
  );
}
