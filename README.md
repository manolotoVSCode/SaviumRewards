# Savium Rewards

Cartera familiar de tarjetas de fidelidad de la suite Savium: puntos, millas y monederos en un solo sitio, con el
código de cada tarjeta listo para enseñarlo en caja (también sin conexión). Cada tarjeta es privada o compartida
con la familia. Solo por invitación.

- **App de iPhone** (`ios/`): SwiftUI, iOS 27, Liquid Glass. Escanea códigos con la cámara (VisionKit).
- **Web** (`web/`): panel de usuario y de administración (miembros e invitaciones, uso, catálogo). Vite + React.
- **Servidor** (`supabase/`): proyecto de Savium Finanzas (`alexhdutnvlxwhziudnr`), tablas `rewards_*`.

Diseño: `docs/superpowers/specs/2026-10-13-savium-rewards-v1-design.md`.
Plan: `docs/superpowers/plans/2026-10-13-savium-rewards-v1.md`.

## Estructura

| Carpeta | Contenido |
|---|---|
| `ios/RewardsCore/` | Paquete Swift con la lógica (validar y codificar códigos, totales por unidad, fusión de cambios, JSON del servidor) y sus pruebas. |
| `ios/SaviumRewards/` | App: `Datos/` (Supabase), `Modelo/` (sesión y almacén local con sincronización), `Vistas/`. |
| `web/src/lib/` | Lógica de la web (misma especificación que `RewardsCore`) y consultas. |
| `shared/fixtures/` | Casos de prueba comunes a Swift y TypeScript (incluye barras de referencia generadas con JsBarcode). |
| `supabase/migrations/` | Esquema `rewards_*`, reglas de acceso y funciones. |
| `supabase/tests/` | Pruebas de reglas de acceso (se ejecutan en una transacción que se deshace). |
| `supabase/functions/` | `rewards-invitar` (invitaciones) y `rewards-cuenta` (eliminar cuenta, quitar miembro, roles, familias). |
| `supabase/semillas/` | Catálogo inicial (borrador por revisar) y arranque de la primera familia. |

## Comandos

```sh
swift test --package-path ios/RewardsCore            # pruebas de la lógica (fuera del sandbox de Claude Code)
cd ios && xcodegen generate                            # el .xcodeproj no se versiona
xcodebuild -project ios/SaviumRewards.xcodeproj -scheme SaviumRewards -destination 'generic/platform=iOS Simulator' build
xcrun simctl launch booted com.savium.rewards -demo YES   # (solo Debug) cartera de demostración sin servidor
cd web && npm install && npm run dev                   # web en http://localhost:8081
cd web && npm test && npm run lint && npm run build
cd web && npm run fixtures:barras                      # regenera las barras de referencia
```

## Servidor

- Cuentas de Supabase Auth con **correo + código de un solo uso**, sin contraseña. **Registro público
  desactivado**: las cuentas las crea `rewards-invitar` (solo administradores).
- Reglas de acceso: cada uno ve sus tarjetas y las **compartidas** de su familia; solo el dueño edita. Las
  privadas no las ve nadie más, tampoco el administrador (que solo ve conteos en `rewards_uso()`).
- Sin borrado físico desde el cliente: `borrado = true`. `sincronizado` lo pone un trigger y es el cursor de la app.
- **Eliminar cuenta**: el usuario de Auth solo se borra si no tiene datos fuera de Rewards
  (`rewards_usuario_solo_rewards`), porque el proyecto es compartido con Finanzas y sus tablas borran en cascada.
- Aislado para poder mudarlo: nada fuera de `rewards_*` lo referencia. Al lanzar, se mueve a un proyecto propio.
- Auditoría de seguridad de Finanzas previa: `docs/auditorias/` (solo en local; no se publica).

## Puesta en marcha (pasos manuales)

1. Aplicar `supabase/migrations/20261013120000_rewards.sql` en el SQL Editor.
2. Authentication → Sign In / Providers: **desactivar «Allow new users to sign up»**.
3. Authentication → Emails → plantilla **Magic Link**: incluir el código `{{ .Token }}` (la app y la web piden el
   código de 6 dígitos, no un enlace).
4. Authentication → Emails → **SMTP propio** (p. ej. Resend): el SMTP integrado de Supabase solo entrega a
   correos del equipo del proyecto y con un límite muy bajo por hora.
5. Ejecutar `supabase/semillas/rewards_inicial.sql` (crea tu familia y te hace administrador).
6. Revisar y ejecutar `supabase/semillas/rewards_catalogo.sql`.
7. Desplegar las funciones: `supabase functions deploy rewards-invitar rewards-cuenta`.
8. Crear el repositorio en GitHub y activar Pages (Settings → Pages → GitHub Actions). La política de
   privacidad queda en `…/SaviumRewards/#/privacidad` (`Config.privacidad` en la app).
9. App Store Connect: app `com.savium.rewards`, icono, capturas (modo `-demo`), cuenta de revisión en una familia
   «Revisión App Store» con tarjetas de ejemplo, y nota de revisión explicando que es solo por invitación.
