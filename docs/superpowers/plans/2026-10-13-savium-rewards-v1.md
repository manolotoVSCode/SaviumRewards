# Savium Rewards v1 — plan de implementación

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [x]`) syntax for tracking.

**Goal:** Cartera familiar de tarjetas de fidelidad (app iOS + web de usuario y administración) sobre el Supabase de Savium Finanzas.

**Architecture:** Tablas `rewards_*` con RLS por dueño y por familia; la app guarda el estado en local (JSON) y sincroniza
con `upsert`/`select` directos protegidos por RLS; la lógica pura vive en `RewardsCore` (Swift) y en `web/src/lib`
(TypeScript) con los mismos casos de prueba (`shared/fixtures`). Invitaciones y borrado de cuenta en Edge Functions.

**Tech Stack:** SwiftUI iOS 27, Swift 6, xcodegen, supabase-swift 2.x, VisionKit, Core Image; Vite + React 18 + TS +
Tailwind + TanStack Query + supabase-js; Postgres/Supabase; Deno (Edge Functions).

**Spec:** `docs/superpowers/specs/2026-10-13-savium-rewards-v1-design.md`

**Estado (2026-10-13):** tareas 1–6 hechas; pendientes los pasos manuales del README y la revisión de diseño.

**Modo de ejecución:** el usuario pidió que se haga solo y se revise el diseño visual al final; se ejecuta en esta
sesión (executing-plans), con revisión final del conjunto.

## Global Constraints

- iOS mínimo 27.0; Swift 6; `bundleIdPrefix: com.savium`; bundle `com.savium.rewards`; equipo `FY5F6RR37J`.
- Única dependencia externa iOS: `supabase-swift` (`from: "2.29.0"`).
- Proyecto Supabase `alexhdutnvlxwhziudnr`; solo tablas/funciones con prefijo `rewards_`; nada de Finanzas se toca.
- Identificadores, textos y comentarios en español; español e inglés en la interfaz.
- Las migraciones no se aplican a producción sin aprobación explícita del usuario; se verifican dentro de una
  transacción con `ROLLBACK`.
- Saldo: entero (`Int64`/`bigint`) 0…1 000 000 000 000.
- `codigo_tipo` ∈ `qr, code128, ean13, ean8, upca, code39, pdf417, aztec, ninguno`.
- Nunca se suman saldos de unidades distintas.

## Review Focus

1. **Tarjeta compartida que pasa a privada** → desaparece de la cartera de los demás en la siguiente sincronización
   (test en `FusionTests.testRetiraFamiliaQueYaNoLlega`).
2. **Edición sin conexión y luego edición más antigua del servidor** → gana la local más reciente y no se pierde
   (test `FusionTests.testGanaLaMasReciente`, `testPendienteNoSePisa`).
3. **EAN-13 mal tecleado** (dígito de control incorrecto, letras, longitud 12) → se rechaza con motivo claro; con 12
   dígitos se ofrece completar el dígito de control (tests `CodigosTests` y `codigos.test.ts`).
4. **Unidades con mayúsculas/espacios distintos** («Puntos», « puntos ») → se agrupan en el mismo total
   (test `TotalesTests.testNormalizaUnidad`).
5. **Un miembro intentando editar/ocultar la tarjeta compartida de otro o leer Finanzas** → RLS lo impide
   (`supabase/tests/rewards_rls.sql`).

---

### Task 1: Esquema, RLS, semilla y pruebas de acceso

**Files:**
- Create: `supabase/migrations/20261013120000_rewards.sql`
- Create: `supabase/tests/rewards_rls.sql`
- Create: `supabase/semillas/rewards_catalogo.sql`

**Interfaces — Produces:** tablas `rewards_programas`, `rewards_familias`, `rewards_miembros`, `rewards_tarjetas`,
`rewards_admins`; funciones `rewards_mi_familia() returns uuid`, `rewards_es_admin() returns boolean`,
`rewards_uso() returns jsonb` (solo admin; conteos agregados); trigger que pone `sincronizado = now()`.
Columnas exactamente como en el spec (snake_case).

- [x] Escribir la migración: tablas con `CHECK`, RLS activado, `revoke all` a `anon`, `grant` mínimos a
  `authenticated` (tarjetas: select/insert/update; miembros: select y `update(nombre, pais, ultima_sincronizacion)`;
  programas/familias/admins: select), funciones auxiliares en esquema `public` con `security definer`,
  `set search_path = ''`, `revoke execute from public, anon`.
- [x] Escribir `rewards_rls.sql`: `begin;` + migración ya aplicada en la misma transacción + usuarios de prueba en
  `auth.users` + `set local role authenticated` + `set local request.jwt.claims` por usuario + aserciones con
  `do $$ ... raise exception ... $$` + `rollback;`. Casos: ve sus privadas; ve compartidas de su familia; no ve
  privadas ajenas; no ve otra familia; no puede `update` la compartida de otro (0 filas); no puede cambiar
  `user_id`; no puede insertar en `rewards_programas`; no lee `transacciones` ni `cuentas` de Finanzas (0 filas);
  `anon` sin privilegios (error 42501).
- [x] Ejecutar migración + pruebas en una sola llamada con `ROLLBACK` vía MCP `execute_sql`. Esperado: sin excepción.
- [x] Escribir semilla del catálogo (insert con `on conflict do nothing`), pendiente de revisión con el usuario.
- [x] Commit.

### Task 2: Edge Functions

**Files:**
- Create: `supabase/functions/rewards-invitar/index.ts`
- Create: `supabase/functions/rewards-cuenta/index.ts` (eliminar cuenta y gestión de miembros por admin)

**Interfaces:** `POST rewards-invitar {email, nombre, familia_id?, rol?}` → `{user_id}`; requiere JWT de admin
(`rewards_admins`). Crea usuario con `auth.admin.createUser({email, email_confirm: true})` (o reutiliza si existe) y
fila en `rewards_miembros` (si no hay `familia_id`, la del admin). `POST rewards-cuenta {accion:"eliminar"}` →
borra tarjetas, miembro y usuario del llamante. `{accion:"quitar", user_id}` (admin) → quita de la familia.

- [x] Escribir ambas funciones con validación de entrada y CORS.
- [x] Comprobar tipos con `deno check` si Deno está instalado; si no, revisión manual.
- [x] Commit.

### Task 3: `shared/fixtures` y `RewardsCore`

**Files:**
- Create: `shared/fixtures/codigos.json` (casos válidos/invalidos por tipo)
- Create: `ios/RewardsCore/Package.swift`
- Create: `ios/RewardsCore/Sources/RewardsCore/{Modelos,Codigos,Barras,Totales,Fusion}.swift`
- Test: `ios/RewardsCore/Tests/RewardsCoreTests/{CodigosTests,BarrasTests,TotalesTests,FusionTests}.swift`

**Interfaces — Produces:**
```swift
public enum TipoCodigo: String, Codable, CaseIterable, Sendable { case qr, code128, ean13, ean8, upca, code39, pdf417, aztec, ninguno }
public enum TipoPrograma: String, Codable, CaseIterable, Sendable { case tarjetaCredito = "tarjeta_credito", aerolinea, hotel, comercio }
public struct Programa: Codable, Identifiable, Hashable, Sendable { id: UUID; nombre; tipo: TipoPrograma; pais: String; color: String; unidad: String; codigoTipo: TipoCodigo; activo: Bool }
public struct Tarjeta: Codable, Identifiable, Hashable, Sendable { id; userId: UUID; programaId: UUID?; nombre: String?; color: String?; unidad: String?; numeroSocio: String?; codigoValor: String?; codigoTipo: TipoCodigo; titular: String?; saldo: Int64?; saldoFecha: String?; caducidad: String?; notas: String?; compartida: Bool; orden: Int; actualizado: Date; sincronizado: Date?; borrado: Bool }
public enum Codigos { static func validar(_ valor: String, tipo: TipoCodigo) -> Resultado; static func digitoControl(_ digitos: String) -> Int? }  // Resultado: .valido / .invalido(Motivo)
public enum Barras { static func modulos(_ valor: String, tipo: TipoCodigo) -> [Bool]? }  // 1D: true = barra
public enum Totales { static func porUnidad(_ tarjetas: [Tarjeta], programas: [UUID: Programa]) -> [(unidad: String, total: Int64)] }
public enum Fusion { static func aplicar(locales: [Tarjeta], pendientes: Set<UUID>, servidor: [Tarjeta]) -> [Tarjeta]; static func reconciliarFamilia(locales: [Tarjeta], servidor: [Tarjeta]) -> [Tarjeta] }
```
- [x] Tests primero (fallan), luego implementación, `swift test --package-path ios/RewardsCore` en verde.
- [x] Commit.

### Task 4: App iOS

**Files:** `ios/project.yml`, `ios/SaviumRewards/App/SaviumRewardsApp.swift`, `Datos/{Config,Nube}.swift`,
`Modelo/{Sesion,Almacen}.swift`, `Vistas/{RaizView,EntrarView,CarteraView,TarjetaVista,DetalleView,EditorView,
CatalogoView,EscanerView,AjustesView,BienvenidaView,FraseSavium,Estilo,CodigoVista}.swift`, `Assets.xcassets`,
`PrivacyInfo.xcprivacy`, `Localizable.xcstrings`, `SaviumRewards.entitlements`.

**Interfaces — Consumes:** RewardsCore. **Produces:** `Almacen` (@Observable): `misTarjetas`, `deFamilia`,
`programas`, `pendientes`, `guardar(_:)`, `borrar(_:)`, `reordenar(_:)`, `sincronizar()`; `Sesion`: `estado`,
`pedirCodigo(email:)`, `verificar(email:codigo:)`, `cerrar()`, `eliminarCuenta()`.

- [x] `xcodegen generate` y compilar vacío.
- [x] Datos + sesión (OTP con `shouldCreateUser: false`), almacén local y sincronización usando `Fusion`.
- [x] Vistas; código con Core Image (QR/PDF417/Aztec/Code128) y `Barras` (EAN/UPC/Code39); brillo al máximo en detalle.
- [x] Escáner con `DataScannerViewController` (comprobar API en SDK de Xcode 27).
- [x] `xcodebuild ... build` sin errores ni avisos de concurrencia. Commit.

### Task 5: Web

**Files:** `web/` (Vite + React + TS + Tailwind), `web/src/lib/{supabase,codigos,totales,tipos}.ts`,
`web/src/lib/codigos.test.ts`, `web/src/pages/{Entrar,Tarjetas,Admin,Privacidad}.tsx`, `.github/workflows/web.yml`.

- [x] `codigos.ts`/`totales.ts` con tests vitest que leen `shared/fixtures/codigos.json`.
- [x] Páginas: entrar (OTP), mis tarjetas + familia (QR con librería `qrcode`, 1D con `jsbarcode`), admin (miembros vía
  `rewards-invitar`/`rewards-cuenta`, uso vía `rewards_uso()`, catálogo), privacidad es/en.
- [x] `npm run build`, `npm test`, `npm run lint` en verde. Commit.

### Task 6: Documentación y entrega

- [x] `README.md`, `CLAUDE.md`, pasos manuales para el usuario (aplicar migración, desactivar registro, plantilla de
  correo con `{{ .Token }}`, SMTP propio, alta de `rewards_admins`, desplegar funciones, GitHub).
- [x] Revisión final del conjunto (agente `code-reviewer`). Commit.
