import type { Config } from "tailwindcss";

// Estilo de la suite Savium: aspecto de iOS (fondos agrupados, tarjetas redondeadas) y el verde Savium.
export default {
  darkMode: "media",
  content: ["./index.html", "./src/**/*.{ts,tsx}"],
  theme: {
    extend: {
      colors: {
        savium: { DEFAULT: "#239005", claro: "#34A815", oscuro: "#4CC22A" },
        fondo: { DEFAULT: "#F2F2F7", oscuro: "#000000" },
        panel: { DEFAULT: "#FFFFFF", oscuro: "#1C1C1E" },
      },
      fontFamily: {
        sans: ["-apple-system", "BlinkMacSystemFont", "SF Pro Text", "Inter", "system-ui", "sans-serif"],
        mono: ["SF Mono", "ui-monospace", "Menlo", "monospace"],
      },
      borderRadius: { tarjeta: "26px" },
    },
  },
} satisfies Config;
