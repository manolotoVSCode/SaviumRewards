export const numero = (n: number) => n.toLocaleString("es-MX");

export function dia(texto: string | null): string | null {
  if (!texto) return null;
  const [a, m, d] = texto.split("-").map(Number);
  if (!a || !m || !d) return null;
  return new Date(a, m - 1, d).toLocaleDateString("es-MX", { day: "numeric", month: "short", year: "numeric" });
}

export function fechaHora(texto: string | null): string {
  if (!texto) return "—";
  return new Date(texto).toLocaleString("es-MX", { dateStyle: "medium", timeStyle: "short" });
}
