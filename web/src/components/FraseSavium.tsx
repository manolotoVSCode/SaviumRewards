import { useEffect, useState } from "react";

const FRASES = [
  "Contando puntos desde 2025", "Sumando millas desde 2025", "Cuidando monederos desde 2025",
  "Coleccionando estrellas desde 2025", "Vigilando la cartera desde 2025", "Ahorrando con estilo desde 2025",
  "Canjeando con cabeza desde 2025", "Volando con puntos desde 2025",
];

/** Una frase distinta cada vez, escrita letra a letra (salvo con «reducir movimiento»). */
export function FraseSavium() {
  const [frase] = useState(() => FRASES[Math.floor(Math.random() * FRASES.length)]);
  const reducir = typeof window !== "undefined" && window.matchMedia("(prefers-reduced-motion: reduce)").matches;
  const [escritas, setEscritas] = useState(reducir ? frase.length : 0);
  useEffect(() => {
    if (escritas >= frase.length) return;
    const t = setTimeout(() => setEscritas((n) => n + 1), escritas === 0 ? 500 : 55);
    return () => clearTimeout(t);
  }, [escritas, frase]);
  return <span aria-label={frase}>{frase.slice(0, escritas)}{escritas < frase.length && <span className="opacity-60">▍</span>}</span>;
}
