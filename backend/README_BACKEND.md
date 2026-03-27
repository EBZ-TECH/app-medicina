# MediConnect Backend (Node.js + MySQL / XAMPP)

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
| **1.1** | Backend Node + MySQL, JWT, `POST /api/auth/register`, `POST /api/auth/login` |
| **1.2** | Perfil `GET /api/profile/me`, sesión en app, `PATCH /api/profile/payment-plan` (paciente) |
| **1.3** | Consultas: `POST /api/consultations`, `GET /api/consultations/specialists`, listados paciente/especialista, `PATCH` fecha, `POST .../pay` simulado |
| **1.4** | Seguimiento clínico `GET /api/patient/monitoring/entries` (categorías y entradas) |
| **1.5** | Fórmulas: API de prescripciones (paciente y especialista), compra y envío simulados |
| **1.6** | Geolocalización en la entrega de fórmula (app Flutter: `geolocator`, mapa externo / vista estática) |
| **1.7** | Calificación del especialista (1–5): tabla `specialist_ratings`, `POST .../rate`, media en `profiles.average_rating` |
| **1.8** | Perfil público del especialista: `bio_short`, `years_experience`, foto (`PATCH /api/profile/specialist-public`), visible al elegir especialista |
| **1.9** | Gestión del especialista: listados reales de consultas, fórmulas y seguimiento/remisiones (`GET` specialist) |

---

## 1) MySQL (XAMPP)

1. Inicia **MySQL/MariaDB** en XAMPP (puerto típico `3306`).
2. El servidor crea automáticamente:
   - la base `MYSQL_DATABASE` (por defecto `appmedicina`)
   - tablas `users` y `profiles`

No necesitas ejecutar SQL manual si usas este backend tal cual. Se crean también tablas `prescriptions` y `prescription_items` (y un ejemplo de fórmula si la base está vacía y existe al menos un paciente), la tabla `specialist_ratings` (calificaciones 1.7) y migraciones en `profiles` (`years_experience`, etc.). En bases ya existentes, al arrancar se añaden a `consultation_requests` las columnas `scheduled_at` y `paid_at` si faltan.

---

## 2) Variables de entorno

Crea un archivo `.env` en esta carpeta `backend/` basado en `.env.example`:

- `PORT` (por defecto `3000`)
- `CORS_ORIGIN` (`*` para pruebas, o una lista separada por coma)
- `JWT_SECRET` (**obligatorio en producción**; cadena larga y aleatoria)
- `MYSQL_HOST`, `MYSQL_PORT`, `MYSQL_USER`, `MYSQL_PASSWORD`, `MYSQL_DATABASE`
- `UPLOADS_DIR` (opcional; carpeta raíz de subidas; por defecto `backend/uploads`)

> No subas `JWT_SECRET` a ningún lugar público.

---

## 3) Ejecutar el backend

En `backend/`:

```powershell
npm install
npm run dev
```

La API queda en:
`http://localhost:3000`

### Reinicio limpio

- **Ctrl+C** en la terminal donde corre Node: el proceso cierra el servidor HTTP y el **pool de MySQL** (evita conexiones colgadas al volver a arrancar).
- Si ves **“El puerto 3000 ya está en uso”**, sigue abierto otro `node` con el mismo `PORT`. Cierra esa terminal, o mata el proceso en el Administrador de tareas, o usa otro `PORT` en `.env`.
- Si falla la conexión a MySQL (**ECONNREFUSED**), arranca **MySQL/XAMPP** antes de `npm run dev`.

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

## 5) Flutter (apuntando a backend local)

Para Android emulator local:

```powershell
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:3000
```

Para Chrome o Windows desktop local:

```powershell
flutter run --dart-define=API_BASE_URL=http://localhost:3000
```

### Geolocalización (1.6)

En la pantalla de detalle de una fórmula (entrega), el botón **Usar mi ubicación actual (GPS)** usa el paquete `geolocator`. En **Android** e **iOS** ya están declarados permisos de ubicación; el usuario debe aceptarlos en el sistema. En emulador Android, configura una ubicación simulada en **Extended controls → Location** si hace falta.

### Recordatorios locales de citas

- La app programa notificaciones locales (aprox. **1 h antes**) cuando una consulta tiene `scheduled_at` en el futuro. Usa `flutter_local_notifications` + `timezone` (sin FCM).
- **Paciente:** `GET /api/patient/consultations` — lista solicitudes con `scheduled_at` / `paid_at` cuando existan.
- **Especialista:** `PATCH /api/specialist/consultations/:id` — body JSON `{ "scheduled_at": "<ISO 8601>" }` para fijar la hora de la cita (debe estar asignada a ese especialista).
- En **Android 13+** hace falta el permiso de notificaciones (la app lo solicita). Tras reinicio del dispositivo, los recordatorios pueden variar según el modo de ahorro de energía del sistema.
