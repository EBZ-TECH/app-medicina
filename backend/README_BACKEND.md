# MediConnect Backend (Node.js + PostgreSQL / Supabase)

**Guía rápida “dónde pego cada variable”:** abre [`CONFIGURACION.md`](CONFIGURACION.md) en esta carpeta y copia la plantilla desde [`.env.example`](.env.example) a `.env`.

Este backend expone una API simple para:

- `POST /api/auth/register` (registro + creación de perfil en `profiles`)
- `POST /api/auth/login` (login con email/password y devuelve JWT)
- `GET /api/profile/me` (lee el perfil del usuario autenticado con `Authorization: Bearer <token>`)
- `GET /api/patient/monitoring/entries` (lista de seguimiento del paciente: resultados, evolución, autorizaciones, recomendaciones, remisiones; query opcional `?category=`)
- `GET /api/patient/consultations` — solicitudes del paciente (`scheduled_at`, `paid_at` cuando existan)
- `GET /api/specialist/consultations` — consultas asignadas al especialista autenticado
- `PATCH /api/specialist/consultations/:id` — programar cita: `{ "scheduled_at": "<ISO 8601>" }`
- `POST /api/patient/consultations/:id/pay` — pago **simulado** de la consulta (`paid_at`; requiere especialista asignado)
- `POST /api/patient/consultations/:id/rate` — calificación **1–5** y comentario opcional (tras la cita o pago simulado; una vez por consulta)
- `PATCH /api/profile/specialist-profile` — especialista: JSON `{ "bio_short": "...", "years_experience": 10 }` (años 0–80 o `null`)
- `GET /api/specialist/prescriptions` — fórmulas emitidas por el especialista
- `GET /api/specialist/monitoring/entries` — seguimiento creado por el especialista (`?category=referral`, etc.)
- **Medicamentos (1.5)** — fórmulas, compra simulada y envío:
  - `GET /api/patient/prescriptions` — fórmulas del paciente autenticado
  - `GET /api/patient/prescriptions/:id` — detalle con ítems
  - `PATCH /api/patient/prescriptions/:id/delivery` — JSON parcial: `delivery_address_line`, `delivery_city`, `delivery_lat`, `delivery_lng`
  - `POST /api/patient/prescriptions/:id/pay` — simula pago (`pending_payment` → `paid`)
  - `POST /api/patient/prescriptions/:id/ship` — inicia envío (`paid` → `shipping`; requiere dirección o ciudad)
  - `POST /api/patient/prescriptions/:id/deliver` — entregado (`shipping` → `delivered`)
  - `POST /api/specialist/prescriptions` — crea fórmula para un paciente: `patient_email` o `patient_user_id`, `title`, `items[]` (`drug_name`, `dosage`, `posology`, `quantity`), opcional `estimated_total_cents` (entero, COP)

Además, soporta subir el archivo de `professionalCard` en el registro de especialistas (se guarda en disco bajo `backend/uploads/professional_cards/`).

### Roadmap alineado (1.1–1.6)

| Fase | Qué cubre en MediConnect |
| --- | --- |
| **1.1** | Backend Node + Postgres (Supabase), JWT, `POST /api/auth/register`, `POST /api/auth/login` |
| **1.2** | Perfil `GET /api/profile/me`, sesión en app, `PATCH /api/profile/payment-plan` (paciente) |
| **1.3** | Consultas: `POST /api/consultations`, `GET /api/consultations/specialists`, listados paciente/especialista, `PATCH` fecha, `POST .../pay` simulado |
| **1.4** | Seguimiento clínico `GET /api/patient/monitoring/entries` (categorías y entradas) |
| **1.5** | Fórmulas: API de prescripciones (paciente y especialista), compra y envío simulados |
| **1.6** | Geolocalización en la entrega de fórmula (app Flutter: `geolocator`, mapa externo / vista estática) |
| **1.7** | Calificación del especialista (1–5): tabla `specialist_ratings`, `POST .../rate`, media en `profiles.average_rating` |
| **1.8** | Perfil público del especialista: `bio_short`, `years_experience`, foto (`PATCH /api/profile/specialist-public`), visible al elegir especialista |
| **1.9** | Gestión del especialista: listados reales de consultas, fórmulas y seguimiento/remisiones (`GET` specialist) |

---

## 1) Base de datos en Supabase (PostgreSQL)

1. En el [panel de Supabase](https://supabase.com/dashboard), abre el proyecto **AppMedicina** (o el que uses).
2. El esquema MediConnect (`users`, `profiles`, `consultation_requests`, `prescriptions`, etc.) puede aplicarse con el MCP de Supabase (`apply_migration`) o con el SQL en `supabase/migrations/20260404180000_initial_mediconnect_schema.sql`.
3. Copia la **Connection string** (URI) en **Project Settings → Database**. Para Node en tu PC o en Render, suele funcionar la conexión **directa** (puerto `5432`, host `db.<ref>.supabase.co`).

Al arrancar el backend, si faltan tablas en una base nueva, `initDb()` las crea de forma idempotente (equivalente al esquema anterior).

---

## 2) Variables de entorno

Crea un archivo `.env` en esta carpeta `backend/` basado en `.env.example`:

- `PORT` (por defecto `3000`)
- `CORS_ORIGIN` (`*` para pruebas, o una lista separada por coma)
- `JWT_SECRET` (**obligatorio en producción**; cadena larga y aleatoria)
- `DATABASE_URL` (URI PostgreSQL de Supabase; ver sección 1)
- `UPLOADS_DIR` (opcional; carpeta raíz de subidas; por defecto `backend/uploads`)

> No subas `JWT_SECRET` ni la contraseña de la base a ningún lugar público.

---

## 3) Ejecutar el backend (local)

En `backend/`:

```powershell
npm install
npm run dev
```

La API queda en:
`http://localhost:3000`

### Despliegue HTTPS (emulador / móvil sin `10.0.2.2`)

Tienes **dos caminos** en Render; elige uno (no hace falta hacer los dos).

#### A) Blueprint con `render.yaml` (panel web de Render)

1. Sube el repo a GitHub/GitLab y en [Render Dashboard](https://dashboard.render.com): **New → Blueprint**.
2. Conecta el repo; Render lee `render.yaml` en la **raíz**. El servicio `appmedicina-api` usa `rootDir: backend`, así que `npm install` / `npm start` se ejecutan **dentro de** `backend/`.
3. Tras el primer deploy, en el servicio → **Environment** añade **`DATABASE_URL`** (URI de Supabase). `JWT_SECRET` puede haberse generado solo; si no, créala a mano.

#### B) MCP de Render (Cursor) — qué hace y qué **no** hace

Revisión del MCP `render` (herramientas expuestas en Cursor):

- **No** hay una acción tipo “aplicar `render.yaml`” o “desplegar Blueprint”. El archivo `render.yaml` **solo** lo usa el flujo **A** en el dashboard.
- **`create_web_service`** crea un Web Service nativo (Node, sin Docker desde el MCP). Parámetros relevantes: `name`, `repo` (URL Git **sin** la rama), `branch`, `runtime: node`, `buildCommand`, `startCommand`, `plan`, `region`, `envVars`, `autoDeploy`.
- **Importante:** en el esquema del MCP **no existe `rootDir`**. El clon de Git queda en la **raíz del repo**; por tanto los comandos deben entrar en `backend/`:
  - `buildCommand`: `cd backend && npm install`
  - `startCommand`: `cd backend && npm start`
- **`update_environment_variables`**: después del deploy, puedes fusionar variables (`serviceId` + lista `key`/`value`). Ahí pegas **`DATABASE_URL`**, y si hace falta **`JWT_SECRET`**, **`NODE_VERSION`** (`20`), **`CORS_ORIGIN`** (`*`), **`PORT`** (`3000`).
- **`list_workspaces`** / **`select_workspace`**: si el MCP dice que no hay workspace, en Cursor debes **elegir workspace de Render** cuando lo pida (no automatizar `select_workspace` sin tu confirmación).
- **`list_services`**, **`get_service`**, **`list_deploys`**, **`list_logs`**: útiles para comprobar estado y URL pública del servicio.

Flujo típico con MCP (resumen): conectar cuenta Render en Cursor → elegir workspace → `create_web_service` con los `cd backend && …` de arriba y `repo` apuntando a tu AppMedicina → `update_environment_variables` con `DATABASE_URL` → copiar la URL `*.onrender.com` para **`API_UPSTREAM`** en Supabase.

#### Después del backend en Render (común a A y B)

1. En **Supabase → Edge Functions → Secrets**, añade **`API_UPSTREAM`** con la URL pública del Node (sin `/` final), p. ej. `https://appmedicina-api.onrender.com`.
2. La Edge Function **`mediconnect`** reenvía el tráfico a ese backend. La app Flutter usa por defecto  
   `https://<ref>.supabase.co/functions/v1/mediconnect`  
   (ref por defecto `howtdxsbatfgxcmhklfc`, configurable con `--dart-define=SUPABASE_PROJECT_REF=...`).

### Reinicio limpio

- **Ctrl+C** en la terminal donde corre Node: el proceso cierra el servidor HTTP y el **pool de Postgres**.
- Si ves **“El puerto 3000 ya está en uso”**, sigue abierto otro `node` con el mismo `PORT`. Cierra esa terminal, o mata el proceso en el Administrador de tareas, o usa otro `PORT` en `.env`.
- Si falla la conexión a PostgreSQL, revisa `DATABASE_URL`, firewall y que el proyecto Supabase esté activo.

---

## 4) Endpoints

### Register (multipart)

`POST /api/auth/register`

Campos (form-data):

- `role`: `"Paciente"` o `"Especialista"`
- `firstName`, `lastName`, `age`, `phone`, `email`, `password`
- `professionalTitle` (Especialista)
- `specialty` (Especialista)
- `professionalCard` (archivo, Especialista, opcional)

### Login (json)

`POST /api/auth/login`

Body:

- `email`
- `password`

Devuelve:

- `access_token` (JWT)
- `refresh_token` (por compatibilidad, hoy es igual que `access_token`)
- `user: { id, email }`
- `role` (en registro)

### Me (token)

`GET /api/profile/me`

Header:

- `Authorization: Bearer <access_token>`

Devuelve:

- `profile` (filas de `profiles`, columnas snake_case como `first_name`, `last_name`, `bio_short`, `years_experience`, `average_rating`, etc.)
- `rating_count` (solo si el rol es **Especialista**: número de calificaciones recibidas)

---

## 5) Flutter (Supabase Edge por defecto)

Por defecto la app usa la Edge Function **mediconnect** en tu proyecto Supabase (requiere `API_UPSTREAM` configurado y backend Node desplegado).

Desarrollo con Node en la misma máquina que el emulador Android:

```powershell
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:3000
```

Chrome o Windows desktop local:

```powershell
flutter run --dart-define=API_BASE_URL=http://localhost:3000
```

Otro proyecto Supabase:

```powershell
flutter run --dart-define=SUPABASE_PROJECT_REF=tu_ref_aqui
```

### Geolocalización (1.6)

En la pantalla de detalle de una fórmula (entrega), el botón **Usar mi ubicación actual (GPS)** usa el paquete `geolocator`. En **Android** e **iOS** ya están declarados permisos de ubicación; el usuario debe aceptarlos en el sistema. En emulador Android, configura una ubicación simulada en **Extended controls → Location** si hace falta.

### Recordatorios locales de citas

- La app programa notificaciones locales (aprox. **1 h antes**) cuando una consulta tiene `scheduled_at` en el futuro. Usa `flutter_local_notifications` + `timezone` (sin FCM).
- **Paciente:** `GET /api/patient/consultations` — lista solicitudes con `scheduled_at` / `paid_at` cuando existan.
- **Especialista:** `PATCH /api/specialist/consultations/:id` — body JSON `{ "scheduled_at": "<ISO 8601>" }` para fijar la hora de la cita (debe estar asignada a ese especialista).
- En **Android 13+** hace falta el permiso de notificaciones (la app lo solicita). Tras reinicio del dispositivo, los recordatorios pueden variar según el modo de ahorro de energía del sistema.
