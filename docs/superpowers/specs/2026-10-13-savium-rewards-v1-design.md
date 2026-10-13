# Savium Rewards v1 — diseño

Fecha: 2026-10-13. Estado: diseño aprobado en conversación; pendiente de revisión del spec escrito.

## Objetivo

Una cartera de tarjetas de fidelidad para la familia: todas las tarjetas y programas de puntos en un solo sitio,
con el código de cada una (QR, código de barras o número de socio) listo para enseñarlo en caja o en el mostrador,
y el saldo de puntos consolidado. App de iPhone más panel web, dentro de la suite Savium.

**Para quién:** de momento, el usuario y su familia. Se diseña como app publicable en la App Store, pero no se
anuncia todavía: se publica en la App Store **listada públicamente, con el registro cerrado** (solo entra quien
haya sido invitado). Decidido por el usuario el 2026-10-13 frente a la app no listada, que Apple podría no
conceder para uso familiar.

**Éxito de la v1:** cada miembro de la familia saca su iPhone en caja, abre Savium Rewards y enseña el código de
su tarjeta (o la compartida de otro miembro) en pocos segundos, incluso sin cobertura; y ve de un vistazo cuántos
puntos/millas tiene en total.

## Alcance

**Entra en la v1**

- App iOS: cartera, detalle con código a pantalla completa, alta/edición con catálogo y escaneo, saldos y
  caducidad a mano, compartir con la familia, funcionamiento sin conexión.
- Web de usuario: ver/añadir/editar tarjetas propias y ver las compartidas de la familia.
- Web de administración (solo administradores): invitar y gestionar miembros, uso, catálogo.

**Fuera de la v1 (decidido)**

- Alertas de caducidad, inactividad o pérdida de estatus.
- Valor de los puntos en dinero y valor total.
- Recomendación de qué tarjeta usar por categoría de gasto.
- Comparador de canjes y transferencias entre programas.
- Apple Wallet (requiere certificado Pass Type ID y firma de pases en servidor).
- Iniciar sesión con Apple (se añade al lanzamiento; con registro cerrado complica la v1 y no es obligatorio
  mientras no haya inicio de sesión con terceros).
- Widget, logos oficiales de marcas, varias familias por usuario, conexión automática con los programas.

## Decisiones de arquitectura

| Decisión | Elegido | Por qué |
|---|---|---|
| Repositorio | Nuevo `SaviumRewards` (local `~/Apps/SaviumRewards`, GitHub nuevo) con `ios/`, `web/`, `supabase/` | El esquema vive en un solo sitio; la familia no entra en la web de Finanzas; lanzar solo exige mover la base de datos. |
| Servidor | Proyecto Supabase de Savium Finanzas (`alexhdutnvlxwhziudnr`), tablas `rewards_*` | Elegido por el usuario mientras no haya usuarios públicos. Al lanzar, la base de datos se mueve a un proyecto propio. |
| Cuentas | Supabase Auth, correo + código de 6 dígitos (OTP), **solo por invitación** | Sin contraseñas; el registro público desactivado impide que nadie ajeno obtenga sesión en el proyecto de Finanzas. |
| App iOS | SwiftUI, **iOS 27 como mínimo**, Liquid Glass, xcodegen (Xcode 27), Swift 6, paquete `RewardsCore` con la lógica; única dependencia externa `supabase-swift` | Mismo patrón que Savium Share y la app de Savium Finanzas, un paso por delante en versión. |
| Web | Vite + React 18 + TypeScript + shadcn/ui + Tailwind + TanStack Query, `HashRouter` | Mismo stack que Savium Finanzas. |
| Despliegue web | Igual que Finanzas (GitHub Pages con Actions). Si el repo es privado y el plan de GitHub no permite Pages privados, se decide en el plan (repo público con `.env` publishable, o alternativa). | — |

### Condiciones de seguridad de la opción B (requisito previo a escribir código)

1. **Auditoría de RLS de Finanzas** (solo lectura): toda tabla de Finanzas debe tener RLS activado y políticas que
   exijan ser el dueño (`auth.uid()`), sin ninguna política que conceda acceso solo por ser `authenticated`.
   También las funciones `SECURITY DEFINER`, vistas y buckets de Storage. Si algo falla, se corrige en Finanzas
   (con su propio cambio y aprobación) antes de crear cualquier cuenta de Rewards.
2. **Registro público desactivado** en Auth del proyecto (comprobar que Finanzas no lo necesita).
3. **Aislamiento:** las tablas `rewards_*` solo referencian `auth.users`; nada de Finanzas referencia `rewards_*`
   ni al revés. Mover a otro proyecto = exportar/importar `rewards_*` y usuarios.
4. **App pública con registro cerrado.** Cualquiera puede descargarla; el registro cerrado es lo que impide
   entrar a quien no esté invitado. La pantalla de entrada lo explica.
5. **Cuenta de revisión de Apple.** La revisión exige una cuenta de prueba: se crea una familia aparte
   («Revisión App Store») con tarjetas de ejemplo. Esa cuenta tiene sesión en el proyecto de Finanzas, por lo
   que la auditoría del punto 1 es obligatoria antes de enviarla a revisión.

## Datos

Todas las tablas con RLS activado. Fechas `timestamptz`. Identificadores `uuid`.

### `rewards_programas` (catálogo)

| Columna | Tipo | Notas |
|---|---|---|
| `id` | uuid PK | |
| `nombre` | text | 1–60 caracteres |
| `tipo` | text | `tarjeta_credito`, `aerolinea`, `hotel`, `comercio` |
| `pais` | text | `MX`, `ES`, `INT` |
| `color` | text | hex `#RRGGBB` |
| `unidad` | text | p. ej. «puntos», «millas», «Avios»; 1–20 caracteres |
| `codigo_tipo` | text | tipo de código habitual (ver lista abajo) |
| `activo` | bool | los inactivos no aparecen al dar de alta |

Lectura: cualquier usuario autenticado que sea miembro de una familia. Escritura: solo `rewards_admins`.

### `rewards_familias`

`id`, `nombre` (1–60), `creada` (default `now()`).

### `rewards_miembros`

| Columna | Tipo | Notas |
|---|---|---|
| `familia_id` | uuid FK | |
| `user_id` | uuid FK `auth.users` | **único**: un usuario, una familia en la v1 |
| `nombre` | text | nombre visible, 1–40 |
| `rol` | text | `admin` («Responsable») o `miembro`; solo una etiqueta dentro de la familia, no da acceso al panel |
| `pais` | text | `MX` o `ES`; país preferido del catálogo |
| `ultima_sincronizacion` | timestamptz | la actualiza el cliente al sincronizar; alimenta el panel de uso |

### `rewards_tarjetas`

| Columna | Tipo | Notas |
|---|---|---|
| `id` | uuid PK | generado en el cliente (permite crear sin conexión) |
| `user_id` | uuid FK `auth.users` | dueño; `default auth.uid()` y no modificable |
| `programa_id` | uuid FK null | null = «Otro programa» |
| `nombre` | text null | obligatorio si `programa_id` es null; 1–60 |
| `color` | text null | hex; si null se usa el del programa |
| `unidad` | text null | si null se usa la del programa |
| `numero_socio` | text null | ≤ 64 |
| `codigo_valor` | text null | contenido del código; ≤ 512 |
| `codigo_tipo` | text | `qr`, `code128`, `ean13`, `ean8`, `upca`, `code39`, `pdf417`, `aztec`, `ninguno` |
| `titular` | text null | ≤ 60 |
| `saldo` | bigint null | 0 … 1 000 000 000 000 |
| `saldo_fecha` | date null | fecha del saldo anotado |
| `caducidad` | date null | |
| `notas` | text null | ≤ 1000 |
| `compartida` | bool | default `false` |
| `orden` | int | orden en la cartera del dueño |
| `actualizado` | timestamptz | lo pone el cliente; gana la última edición |
| `sincronizado` | timestamptz | lo pone el servidor (trigger); cursor de descarga |
| `borrado` | bool | default `false`; nada se borra físicamente |

Restricciones `CHECK` para longitudes, rangos, valores permitidos y coherencia (`codigo_tipo = 'ninguno'` ⇔
`codigo_valor` null).

### `rewards_admins`

`user_id` PK. Se rellena a mano por SQL (el usuario). Da acceso al panel de administración.

### Reglas de acceso (RLS)

Función auxiliar `rewards_mi_familia()` (`SECURITY DEFINER`, `search_path` fijo) que devuelve la familia del
usuario actual; `rewards_es_admin()` igual para administradores.

- **Tarjetas, leer:** `user_id = auth.uid()` **o** (`compartida` y el dueño es de mi familia).
  Las privadas solo las ve su dueño, ni siquiera el administrador.
- **Tarjetas, crear/editar:** solo `user_id = auth.uid()`. La familia ve las compartidas pero no las edita.
  No existe política de `DELETE` (borrado lógico).
- **Miembros, leer:** los de mi familia. Escribir: el propio usuario solo su fila y solo las columnas `nombre`,
  `pais` y `ultima_sincronizacion` (privilegio `UPDATE` por columnas para `authenticated`); altas, roles y bajas
  solo la Edge Function de invitación o un administrador desde la web (también vía Edge Function).
- **Familias, leer:** la mía. Escribir: solo administradores.
- **Programas:** ver arriba.
- `anon` sin privilegios en ninguna tabla `rewards_*`.

### Invitaciones

Edge Function `rewards-invitar` (requiere sesión de administrador): recibe correo, nombre y familia; crea el
usuario con la API de administración (`service_role`, sin enviar enlace de registro público) y su fila en
`rewards_miembros`. El invitado entra con correo + código. Si el correo no está invitado, el OTP no crea
usuario (registro desactivado) y la app muestra «Esta app es solo por invitación».

### Catálogo inicial (semilla)

Se carga con un script SQL separado de la migración del esquema. Colores aproximados de marca; sin logos.

- **México:** Club Premier (Aeroméxico), Viva Aerobus, Volaris v.club, BBVA Puntos, Banamex Puntos, Santander
  Puntos, Banorte Puntos, HSBC Puntos, American Express Membership Rewards MX, Soriana Recompensas, Liverpool
  Monedero, Sanborns, Walmart/Bodega Cashi, Chedraui Monedero, OXXO Spin Premia, Farmacias del Ahorro, Costco
  México (membresía), Cinépolis Club, Starbucks Rewards MX, PetroSeven/Orsan (gasolineras).
- **España:** Iberia Club (Avios), Vueling Club (Avios), Air Europa SUMA, Travel Club, Carrefour Club, El Corte
  Inglés, DIA Club, Eroski Club, Repsol Waylet, Cepsa/Moeve, Renfe Más, BBVA Puntos ES, Santander ES,
  American Express Membership Rewards ES, IKEA Family, Decathlon.
- **Internacional:** Marriott Bonvoy, Hilton Honors, IHG One Rewards, World of Hyatt, Accor ALL, LifeMiles,
  Flying Blue, AAdvantage, United MileagePlus, Delta SkyMiles.

La lista exacta, sus colores, unidades y tipos de código se revisan con el usuario antes de sembrar (ver memoria
«Verificar contenido antes de sembrar»).

## App iOS

### Estilo

Sigue el modelo de Savium Share y de la app de Savium Finanzas, con lo nuevo de iOS 27:

- Componentes nativos con Liquid Glass (barras, `TabView`, botones flotantes, hojas), títulos grandes, SF
  Symbols, Dynamic Type, modo oscuro automático. Sin estilos inventados.
- Se reutiliza de Share: `Estilo.swift` (verde Savium exacto como acento), las tarjetas estilo Wallet, la
  transición *zoom* de la tarjeta a su detalle, la bienvenida en páginas, las frases de Savium y los hápticos.
- Icono con el mismo lenguaje que los de la suite.
- APIs nuevas de iOS 27: antes de usar cada una se comprueba en la documentación del SDK de Xcode 27 (no se
  asume nada de memoria). Candidatas a valorar en el plan: mejoras de Liquid Glass y de transiciones,
  escaneo de códigos en VisionKit y lo que el SDK ofrezca para pases y tarjetas.

### Pantallas

- **Entrar:** correo → código de 6 dígitos. Mensaje claro si no hay invitación.
- **Cartera** (inicio): tarjetas apiladas estilo Wallet con el color del programa, en dos secciones, «Mías» y
  «De la familia» (con el nombre del dueño). Arriba, el total por unidad (p. ej. «48 200 puntos · 31 500
  millas»); unidades distintas nunca se suman. Buscador. Reordenar arrastrando (solo «Mías»).
- **Detalle:** código grande generado en el dispositivo (Core Image para QR, Code 128, PDF417 y Aztec; generador
  propio en `RewardsCore` para EAN-13/EAN-8/UPC-A/Code 39), número de socio copiable, brillo al máximo mientras
  está abierta (se restaura al salir), saldo, fecha del saldo, caducidad, notas. Las tarjetas de la familia se
  muestran en solo lectura.
- **Añadir / editar:** catálogo filtrado por el país del usuario (con buscador y pestaña «Todos») u «Otro
  programa» → escanear con VisionKit `DataScannerViewController` (detecta tipo y contenido) o escribir a mano →
  saldo, fecha del saldo y caducidad opcionales → interruptor «Compartir con la familia». Borrar con
  confirmación.
- **Ajustes:** nombre, familia (miembros), país del catálogo, idioma (sigue al sistema), cerrar sesión,
  **eliminar mi cuenta** (lo exige la App Store; borra sus tarjetas y su fila de miembro mediante una Edge
  Function), política de privacidad, versión.

Español e inglés; modo claro y oscuro; textos y comentarios del código en español.

### Datos locales y sincronización

- Estado local en JSON en Application Support (como `Almacen` de Share): tarjetas propias, tarjetas de la
  familia, catálogo, cambios pendientes y cursor.
- Al abrir, al volver la red, al volver a primer plano y tras cada cambio: subir pendientes (`upsert` por `id`,
  solo propias) y bajar filas con `sincronizado > cursor` (propias y compartidas de la familia) y el catálogo.
- Conflictos: gana el `actualizado` más reciente; el trigger del servidor ignora una escritura con `actualizado`
  anterior al guardado (un iPhone que vuelve de estar sin conexión no pisa una edición posterior).
- Una tarjeta que el servidor rechaza no bloquea la sincronización del resto: queda marcada y pendiente.
- Los opcionales vacíos viajan como `null` explícito para que vaciar un campo también llegue al servidor.
- Tarjetas de la familia: como RLS deja de devolver una tarjeta cuando su dueño la hace privada, el cliente no
  usa el cursor para ellas; en cada sincronización baja la lista completa de tarjetas compartidas de la familia
  (son pocas) y retira las locales que ya no aparezcan.
- Sesión: tokens de Supabase en el Llavero. Sesión caducada → volver a pedir el código sin perder pendientes.

### `RewardsCore` (paquete Swift, con pruebas)

- Modelos (`Tarjeta`, `Programa`, `TipoCodigo`).
- Validación de códigos: dígito de control EAN-13/EAN-8/UPC-A, juego de caracteres de Code 39/Code 128,
  longitudes.
- Generación de códigos 1D sin dependencia de UIKit (matriz de barras), para probarla.
- Totales consolidados por unidad.
- Fusión de cambios (última edición gana, borrado lógico, pendientes vs. servidor).

## Web

> Cambio 2026-10-13: la web vive dentro de Savium Finanzas (menú Apps → Savium Rewards, con la sesión de Finanzas),
> porque solo la usa el titular; la familia usa la app. Privacidad en savium.manoloto.com/privacidad-rewards.html.

Vite + React + shadcn, `HashRouter`, Supabase JS con `VITE_SUPABASE_URL` y `VITE_SUPABASE_PUBLISHABLE_KEY`.

- **Entrar:** correo + código.
- **Mis tarjetas:** tabla y vista de tarjetas; alta/edición con el mismo formulario y validaciones (sin cámara:
  el código se escribe); la de la familia en solo lectura, con el código visible por si hay que enseñarlo.
- **Administración** (solo si `rewards_es_admin()`):
  - Miembros: invitar por correo (llama a `rewards-invitar`), cambiar nombre/rol, quitar de la familia.
  - Uso: usuarios, última sincronización, número de tarjetas, tarjetas por programa (conteos agregados; nunca
    el contenido de tarjetas privadas ajenas).
  - Catálogo: alta, edición y desactivación de programas.

Lógica pura (validación de códigos, totales) en `web/src/lib/` con pruebas vitest; misma especificación que
`RewardsCore`, comprobada con los mismos casos de prueba.

## Distribución

- App Store, **listada públicamente con registro cerrado**. Revisión normal de Apple.
- Requisitos de revisión: cuenta de prueba (familia «Revisión App Store»), política de privacidad publicada en
  la web de Rewards (es/en, como la de Share), manifiesto de privacidad y etiquetas de privacidad de la App
  Store (correo y contenido del usuario, sin seguimiento), eliminación de cuenta dentro de la app.
- **Riesgo de revisión:** una app que solo sirve con invitación puede recibir preguntas de Apple (guía 4.2 /
  2.1). Se mitiga con la cuenta de prueba, una explicación en las notas de revisión y una pantalla de entrada
  que explique que es para familias invitadas. Si la rechazan, alternativa: pedir la distribución no listada.

## Errores

- **Sin conexión:** la cartera y los códigos funcionan igual; los cambios quedan pendientes con un aviso
  discreto «Pendiente de sincronizar».
- **Código ilegible o inválido:** se valida antes de guardar; siempre se puede guardar solo el número de socio
  (`codigo_tipo = 'ninguno'`).
- **Datos inválidos en el servidor:** los rechazan las restricciones `CHECK`; el cliente muestra el error de esa
  tarjeta y conserva la versión local para corregirla.
- **Fallo de red al subir:** reintento en la siguiente oportunidad; nunca se pierde un cambio pendiente.

## Pruebas

- `swift test` en `RewardsCore`: validación y generación de códigos, totales, fusión de cambios.
- `vitest` en la web: lógica pura y visibilidad del panel de administración.
- **Script SQL de reglas de acceso** (`supabase/tests/`), con usuarios de prueba: un miembro no ve tarjetas
  privadas ajenas; no puede editar ni ocultar las compartidas de otro; no ve tarjetas de otra familia; no puede
  escribir en el catálogo ni en `rewards_admins`; una cuenta de Rewards no lee ninguna tabla de Finanzas; `anon`
  no lee nada.
- Prueba manual en simulador y en dispositivo: escanear tarjetas reales de cada tipo de código y que el lector
  de caja las acepte desde la pantalla.

## Orden de trabajo previsto (lo concreta el plan)

1. Auditoría de seguridad de Finanzas y registro desactivado (requisito previo).
2. Migración `rewards_*` + pruebas de RLS + Edge Function de invitación.
3. `RewardsCore` con pruebas.
4. App iOS.
5. Web de usuario y administración.
6. Semilla del catálogo (revisada antes con el usuario).
7. Publicación en la App Store (ver «Distribución»).

Las migraciones las aplica el usuario (SQL Editor o con su aprobación explícita), y el código que dependa de ellas
se despliega después.
