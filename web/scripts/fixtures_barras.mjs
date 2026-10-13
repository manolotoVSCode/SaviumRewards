// Genera los casos de referencia de barras (shared/fixtures/codigos.json → "barras") con JsBarcode,
// una implementación independiente, para comprobar el codificador propio de RewardsCore.
import { readFileSync, writeFileSync } from "node:fs";
import JsBarcode from "jsbarcode";

const ruta = new URL("../../shared/fixtures/codigos.json", import.meta.url);
const casos = JSON.parse(readFileSync(ruta, "utf8"));
const formato = { ean13: "EAN13", ean8: "EAN8", upca: "UPC", code39: "CODE39" };
const entradas = [
  ["ean13", "4006381333931"], ["ean13", "5901234123457"], ["ean13", "0036000291452"],
  ["ean8", "96385074"], ["upca", "036000291452"], ["code39", "ABC-123"], ["code39", "SOCIO 42/A"],
];

casos.barras = entradas.map(([tipo, valor]) => {
  const salida = {};
  JsBarcode(salida, valor, { format: formato[tipo], flat: true });
  return { tipo, valor, modulos: salida.encodings.map((e) => e.data).join("") };
});
writeFileSync(ruta, JSON.stringify(casos, null, 2) + "\n");
console.log(casos.barras.map((b) => `${b.tipo} ${b.valor}: ${b.modulos.length} módulos`).join("\n"));
