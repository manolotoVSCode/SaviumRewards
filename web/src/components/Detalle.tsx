import { Copy, Pencil } from "lucide-react";
import { Modal } from "./Modal";
import { Codigo } from "./Codigo";
import { TarjetaWeb } from "./TarjetaWeb";
import { titulo, unidadDe, type Programa, type Tarjeta } from "@/lib/tipos";
import { dia, numero } from "@/lib/formato";

export function Detalle({ tarjeta, programa, dueno, onEditar, onCerrar }: {
  tarjeta: Tarjeta; programa?: Programa; dueno?: string; onEditar?: () => void; onCerrar: () => void;
}) {
  const filas: [string, string | null][] = [
    ["Titular", tarjeta.titular],
    ["Saldo", tarjeta.saldo !== null ? `${numero(tarjeta.saldo)} ${unidadDe(tarjeta, programa)}` : null],
    ["Saldo a fecha de", dia(tarjeta.saldo_fecha)],
    ["Caducidad", dia(tarjeta.caducidad)],
    ["Notas", tarjeta.notas],
    ["De", dueno ?? null],
  ];
  return (
    <Modal titulo={titulo(tarjeta, programa)} onCerrar={onCerrar}>
      <div className="space-y-4">
        <TarjetaWeb tarjeta={tarjeta} programa={programa} dueno={dueno} />
        {tarjeta.codigo_valor && tarjeta.codigo_tipo !== "ninguno" && (
          <>
            <Codigo valor={tarjeta.codigo_valor} tipo={tarjeta.codigo_tipo} />
            <p className="text-center font-mono text-sm text-black/50 dark:text-white/50">{tarjeta.codigo_valor}</p>
          </>
        )}
        <div className="panel divide-y divide-black/5 dark:divide-white/10">
          {tarjeta.numero_socio && (
            <div className="flex items-center justify-between px-4 py-3">
              <div><span className="etiqueta">Número de socio</span><span className="font-mono">{tarjeta.numero_socio}</span></div>
              <button className="boton-secundario h-9 w-9 p-0" aria-label="Copiar"
                onClick={() => navigator.clipboard.writeText(tarjeta.numero_socio ?? "")}><Copy size={16} /></button>
            </div>
          )}
          {filas.filter(([, v]) => v).map(([k, v]) => (
            <div key={k} className="px-4 py-3"><span className="etiqueta">{k}</span><span className="whitespace-pre-wrap">{v}</span></div>
          ))}
        </div>
        {onEditar && <button className="boton-secundario w-full" onClick={onEditar}><Pencil size={16} />Editar</button>}
      </div>
    </Modal>
  );
}
