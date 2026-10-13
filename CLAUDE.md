# Savium Rewards — notas para agentes

- Ver README.md para estructura, comandos y modelo de servidor; el diseño está en docs/superpowers/specs.
- Identificadores, textos y comentarios en español, breves.
- El `.xcodeproj` se genera con `xcodegen generate` (en `ios/`); no editarlo a mano.
- La lógica va en `ios/RewardsCore` (Swift) y, para la web, en `src/lib/rewards` del repo de Savium Finanzas
  (TypeScript), con la misma especificación; los casos viven en `shared/fixtures/` (con copia en Finanzas).
- Servidor: proyecto de Supabase de Savium Finanzas. **No tocar nada que no empiece por `rewards_`.** Las
  migraciones no se aplican a producción sin aprobación explícita del usuario; para probarlas, ejecutarlas junto
  con `supabase/tests/rewards_rls.sql` dentro de `begin; … rollback;`.
- Nunca borrar usuarios de Auth sin `rewards_usuario_solo_rewards` (las tablas de Finanzas borran en cascada).
- En el sandbox de Claude Code, `swift test`, `xcodebuild` y `simctl` necesitan ejecutarse fuera del sandbox; npm
  necesita `npm_config_cache=$TMPDIR/npm-cache`.
