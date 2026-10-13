import { useMemo, useState } from "react";
import { Modal } from "./Modal";
import { Codigo } from "./Codigo";
import { completar, MOTIVOS, normalizar, validar } from "@/lib/codigos";
import { NOMBRE_TIPO_CODIGO, NOMBRE_TIPO_PROGRAMA, SALDO_MAXIMO, TIPOS_CODIGO, TIPOS_PROGRAMA, type Programa, type Tarjeta, type TipoCodigo } from "@/lib/tipos";
import { useGuardarTarjeta } from "@/lib/datos";

const COLORES = ["#4F8248", "#4F837F", "#5B7397", "#726A98", "#86698A", "#A56C7E", "#A87B5A", "#A46F62", "#968551", "#676E77"];
const OTRO = "otro";

export function Editor({ inicial, nueva, programas, pais, onCerrar }: {
  inicial: Tarjeta; nueva: boolean; programas: Programa[]; pais: string; onCerrar: () => void;
}) {
  const [t, setT] = useState<Tarjeta>(inicial);
  const [valor, setValor] = useState(inicial.codigo_valor ?? "");
  const [saldo, setSaldo] = useState(inicial.saldo?.toString() ?? "");
  const [todos, setTodos] = useState(false);
  const guardar = useGuardarTarjeta();
  const cambiar = (c: Partial<Tarjeta>) => setT((x) => ({ ...x, ...c }));

  const programa = programas.find((p) => p.id === t.programa_id);
  const motivo = validar(valor, t.codigo_tipo);
  const saldoNumero = saldo.replace(/\D/g, "") === "" ? null : Number(saldo.replace(/\D/g, ""));
  const saldoValido = saldoNumero === null || saldoNumero <= SALDO_MAXIMO;
  const nombreValido = !!t.programa_id || !!t.nombre?.trim();
  const puedeGuardar = motivo === null && saldoValido && nombreValido && !guardar.isPending;
  const visibles = useMemo(() => programas.filter((p) => p.activo && (todos || p.pais === pais || p.pais === "INT")), [programas, todos, pais]);

  function elegirPrograma(id: string) {
    if (id === OTRO) return cambiar({ programa_id: null, color: t.color ?? COLORES[0] });
    const p = programas.find((x) => x.id === id);
    if (!p) return;
    cambiar({ programa_id: p.id, nombre: null, color: null, unidad: null, ...(valor ? {} : { codigo_tipo: p.codigo_tipo }) });
  }

  async function enviar() {
    const limpio = (s: string | null) => (s?.trim() ? s.trim() : null);
    await guardar.mutateAsync({
      ...t,
      nombre: t.programa_id ? null : limpio(t.nombre), unidad: limpio(t.unidad), numero_socio: limpio(t.numero_socio),
      titular: limpio(t.titular), notas: limpio(t.notas),
      codigo_valor: t.codigo_tipo === "ninguno" ? null : normalizar(valor, t.codigo_tipo),
      saldo: saldoNumero,
    });
    onCerrar();
  }

  async function borrar() {
    if (!confirm("¿Borrar esta tarjeta? También desaparecerá de la cartera de tu familia.")) return;
    // Se borra la versión guardada, no lo que se estaba editando.
    await guardar.mutateAsync({ ...inicial, borrado: true });
    onCerrar();
  }

  return (
    <Modal titulo={nueva ? "Nueva tarjeta" : "Editar tarjeta"} onCerrar={onCerrar}>
      <div className="space-y-5">
        <section className="panel space-y-3 p-4">
          <div className="flex items-center justify-between">
            <label className="etiqueta" htmlFor="programa">Programa</label>
            <label className="flex items-center gap-1.5 text-xs text-black/50 dark:text-white/50">
              <input type="checkbox" checked={todos} onChange={(e) => setTodos(e.target.checked)} />Todos los países
            </label>
          </div>
          <select id="programa" className="campo" value={t.programa_id ?? (nueva && !t.nombre && !t.color ? "" : OTRO)}
            onChange={(e) => elegirPrograma(e.target.value)}>
            <option value="" disabled>Elegir programa…</option>
            {TIPOS_PROGRAMA.map((tipo) => (
              <optgroup key={tipo} label={NOMBRE_TIPO_PROGRAMA[tipo]}>
                {visibles.filter((p) => p.tipo === tipo).map((p) => <option key={p.id} value={p.id}>{p.nombre}</option>)}
              </optgroup>
            ))}
            <option value={OTRO}>Otro programa</option>
          </select>
          {!t.programa_id && (t.color || t.nombre) && (
            <>
              <input className="campo" placeholder="Nombre de la tarjeta" maxLength={60} value={t.nombre ?? ""} onChange={(e) => cambiar({ nombre: e.target.value })} />
              <input className="campo" placeholder="Unidad (puntos, millas…)" maxLength={20} value={t.unidad ?? ""} onChange={(e) => cambiar({ unidad: e.target.value })} />
              <div className="flex flex-wrap gap-2">
                {COLORES.map((c) => (
                  <button key={c} aria-label={`Color ${c}`} onClick={() => cambiar({ color: c })}
                    className={`h-8 w-8 rounded-full ${t.color === c ? "ring-2 ring-offset-2 ring-savium" : ""}`} style={{ background: c }} />
                ))}
              </div>
            </>
          )}
          {!nombreValido && <p className="text-xs text-red-600">Elige un programa o escribe el nombre de la tarjeta.</p>}
        </section>

        <section className="panel space-y-3 p-4">
          <label className="etiqueta" htmlFor="tipo">Código</label>
          <select id="tipo" className="campo" value={t.codigo_tipo}
            onChange={(e) => { const tipo = e.target.value as TipoCodigo; cambiar({ codigo_tipo: tipo }); if (tipo === "ninguno") setValor(""); }}>
            {TIPOS_CODIGO.map((c) => <option key={c} value={c}>{NOMBRE_TIPO_CODIGO[c]}</option>)}
          </select>
          {t.codigo_tipo !== "ninguno" && (
            <>
              <input className="campo font-mono" placeholder="Contenido del código" maxLength={512} value={valor} onChange={(e) => setValor(e.target.value)} />
              {motivo && valor && <p className="text-xs text-red-600">{MOTIVOS[motivo]}</p>}
              {motivo && completar(valor, t.codigo_tipo) && (
                <button className="text-sm font-semibold text-savium" onClick={() => setValor(completar(valor, t.codigo_tipo)!)}>
                  Usar {completar(valor, t.codigo_tipo)}
                </button>
              )}
              {!motivo && <Codigo valor={valor} tipo={t.codigo_tipo} />}
            </>
          )}
          <input className="campo font-mono" placeholder="Número de socio" maxLength={64} value={t.numero_socio ?? ""} onChange={(e) => cambiar({ numero_socio: e.target.value })} />
        </section>

        <section className="panel grid gap-3 p-4 sm:grid-cols-2">
          <div className="sm:col-span-2">
            <label className="etiqueta" htmlFor="saldo">Saldo ({t.unidad || programa?.unidad || "puntos"})</label>
            <input id="saldo" className="campo tabular-nums" inputMode="numeric" value={saldo} onChange={(e) => setSaldo(e.target.value)} />
            {!saldoValido && <p className="mt-1 text-xs text-red-600">El saldo no es válido.</p>}
          </div>
          <div>
            <label className="etiqueta" htmlFor="fsaldo">Saldo a fecha de</label>
            <input id="fsaldo" type="date" className="campo" value={t.saldo_fecha ?? ""} onChange={(e) => cambiar({ saldo_fecha: e.target.value || null })} />
          </div>
          <div>
            <label className="etiqueta" htmlFor="caduca">Caducidad</label>
            <input id="caduca" type="date" className="campo" value={t.caducidad ?? ""} onChange={(e) => cambiar({ caducidad: e.target.value || null })} />
          </div>
          <input className="campo sm:col-span-2" placeholder="Titular" maxLength={60} value={t.titular ?? ""} onChange={(e) => cambiar({ titular: e.target.value })} />
          <textarea className="campo sm:col-span-2" rows={3} placeholder="Notas" maxLength={1000} value={t.notas ?? ""} onChange={(e) => cambiar({ notas: e.target.value })} />
        </section>

        <label className="panel flex items-center justify-between gap-4 p-4">
          <span><span className="font-medium">Compartir con la familia</span>
            <span className="block text-xs text-black/50 dark:text-white/50">Tu familia podrá verla y enseñar su código. Solo tú puedes cambiarla.</span></span>
          <input type="checkbox" className="h-5 w-5 accent-savium" checked={t.compartida} onChange={(e) => cambiar({ compartida: e.target.checked })} />
        </label>

        {guardar.error && <p className="text-sm text-red-600">No se pudo guardar: {guardar.error.message}</p>}
        <div className="flex gap-3">
          {!nueva && <button className="boton-secundario text-red-600" onClick={borrar}>Borrar</button>}
          <button className="boton-principal flex-1" disabled={!puedeGuardar} onClick={enviar}>Guardar</button>
        </div>
      </div>
    </Modal>
  );
}
