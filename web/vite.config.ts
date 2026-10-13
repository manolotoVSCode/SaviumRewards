/// <reference types="vitest" />
import { defineConfig } from "vite";
import react from "@vitejs/plugin-react-swc";
import path from "path";

// Publicado en GitHub Pages bajo /SaviumRewards/ con HashRouter (sin reglas de reescritura).
export default defineConfig({
  base: "./",
  server: { host: "::", port: 8081 },
  plugins: [react()],
  // bwip-js (≈1 MB) va en su propio trozo y se carga solo al dibujar un código.
  build: { chunkSizeWarningLimit: 1100 },
  resolve: { alias: { "@": path.resolve(__dirname, "./src") } },
  test: { include: ["src/**/*.test.ts"] },
});
