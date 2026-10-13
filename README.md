# Savium Rewards

Cartera familiar de tarjetas de fidelidad de la suite Savium: puntos, millas y monederos en un solo sitio, con el
código de cada tarjeta listo para enseñarlo en caja (también sin conexión). Cada tarjeta es privada o compartida
con la familia. Solo por invitación.

- **App de iPhone** (`ios/`): SwiftUI, iOS 27, Liquid Glass. Escanea códigos con la cámara (VisionKit).
- **Web**: vive dentro de Savium Finanzas (menú Apps → Savium Rewards; `src/pages/SaviumRewards.tsx` del repo
  `saviumfinanzas`): tarjetas, familia, miembros e invitaciones, uso y catálogo. Política de privacidad en
  https://savium.manoloto.com/privacidad-rewards.html.
- **Servidor** (`supabase/`): proyecto de Savium Finanzas (`alexhdutnvlxwhziudnr`), tablas `rewards_*`.

Diseño: `docs/superpowers/specs/2026-10-13-savium-rewards-v1-design.md`.
Plan: `docs/superpowers/plans/2026-10-13-savium-rewards-v1.md`.

## Estructura

| Carpeta | Contenido |
|---|---|
| `ios/RewardsCore/` | Paquete Swift con la lógica (validar y codificar códigos, totales por unidad, fusión de cambios, JSON del servidor) y sus pruebas. |
| `ios/SaviumRewards/` | App: `Datos/` (Supabase), `Modelo/` (sesión y almacén local con sincronización), `Vistas/`. |
| `shared/fixtures/` | Casos de prueba de códigos (incluye barras de referencia generadas con JsBarcode). Finanzas tiene una copia en `shared/fixtures/rewards-codigos.json` para su `src/lib/rewards`: si cambian, actualizar las dos. |
| `supabase/migrations/` | Esquema `rewards_*`, reglas de acceso y funciones. |
| `supabase/tests/` | Pruebas de reglas de acceso (se ejecutan en una transacción que se deshace). |
| `supabase/functions/` | `rewards-codigo` (envía el código de acceso solo a miembros), `rewards-invitar` (invitaciones) y `rewards-cuenta` (eliminar cuenta, quitar miembro, roles, familias). |
| `supabase/semillas/` | Catálogo inicial (borrador por revisar) y arranque de la primera familia. |

## Comandos

```sh
swift test --package-path ios/RewardsCore            # pruebas de la lógica (fuera del sandbox de Claude Code)
cd ios && xcodegen generate                            # el .xcodeproj no se versiona
xcodebuild -project ios/SaviumRewards.xcodeproj -scheme SaviumRewards -destination 'generic/platform=iOS Simulator' build
xcrun simctl launch booted com.savium.rewards -demo YES   # (solo Debug) cartera de demostración sin servidor
```

## Servidor

- Cuentas de Supabase Auth con **correo + código de un solo uso** (o contraseña, si la cuenta la tiene: el titular
  y la cuenta de revisión de Apple). **Registro público desactivado** (comprobado: `signup_disabled`); las cuentas
  las crea `rewards-invitar` (solo administradores) y el código solo lo envía `rewards-codigo` a miembros.
- **Face ID** al abrir y al volver, como en Savium Finanzas (`Bloqueo`, regla en `RewardsCore`).
- Reglas de acceso: cada uno ve sus tarjetas y las **compartidas** de su familia; solo el dueño edita. Las
  privadas no las ve nadie más, tampoco el administrador (que solo ve conteos en `rewards_uso()`).
- Sin borrado físico desde el cliente: `borrado = true`. `sincronizado` lo pone un trigger y es el cursor de la app.
- **Eliminar cuenta**: el usuario de Auth solo se borra si no tiene datos fuera de Rewards
  (`rewards_usuario_solo_rewards`), porque el proyecto es compartido con Finanzas y sus tablas borran en cascada.
- Aislado para poder mudarlo: nada fuera de `rewards_*` lo referencia. Al lanzar, se mueve a un proyecto propio.
- Auditoría de seguridad de Finanzas previa: `docs/auditorias/` (solo en local; no se publica).

## Puesta en marcha

Hecho el 2026-10-13: migración, registro público desactivado, plantilla de correo con `{{ .Token }}`, SMTP de
iCloud, familia inicial con el titular como administrador, catálogo, Edge Functions y web dentro de Finanzas
(Web 10.1). Lista original:

1. Aplicar `supabase/migrations/20261013120000_rewards.sql` en el SQL Editor.
2. Authentication → Sign In / Providers: **desactivar «Allow new users to sign up»**.
3. Authentication → Emails → plantilla **Magic Link**: incluir el código `{{ .Token }}` (la app y la web piden el
   código de 6 dígitos, no un enlace).
4. Authentication → Emails → **SMTP propio** (p. ej. Resend): el SMTP integrado de Supabase solo entrega a
   correos del equipo del proyecto y con un límite muy bajo por hora.
5. Ejecutar `supabase/semillas/rewards_inicial.sql` (crea tu familia y te hace administrador).
6. Revisar y ejecutar `supabase/semillas/rewards_catalogo.sql`.
7. Desplegar las funciones: `supabase functions deploy rewards-invitar rewards-cuenta`.
8. Web y política de privacidad: dentro de Savium Finanzas (Web 10.1).
9. App Store Connect: app `com.savium.rewards`, icono, capturas (modo `-demo`), cuenta de revisión en una familia
   «Revisión App Store» con tarjetas de ejemplo, y nota de revisión explicando que es solo por invitación.
