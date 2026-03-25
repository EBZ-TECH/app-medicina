# MediConnect Backend (Node.js + Supabase)

Este backend expone una API simple para:
- `POST /api/auth/register` (registro + creación de perfil en `profiles`)
- `POST /api/auth/login` (login con email/password y devuelve tokens)
- `GET /api/profile/me` (lee el perfil del usuario autenticado con `Authorization: Bearer <token>`)

Además, soporta subir el archivo de `professionalCard` en el registro de especialistas.

---

## 1) Requisitos en Supabase

En tu proyecto de Supabase:
1. Abre **SQL Editor**.
2. Ejecuta el archivo: `supabase/migrations/001_init.sql`
3. (Opcional) Verifica que exista el bucket de Storage `professional_cards`.
   - El SQL intenta crear el bucket si no existe.

Si tu proyecto no tiene Auth habilitado, habilita **Email/Password** en Supabase Auth.

---

## 2) Variables de entorno

Crea un archivo `.env` en esta carpeta `backend/` basado en `.env.example`:

- `SUPABASE_URL`
- `SUPABASE_ANON_KEY`
- `SUPABASE_SERVICE_ROLE_KEY`
- `PROFESSIONAL_CARDS_BUCKET` (por defecto `professional_cards`)
- `PORT` (por defecto `3000`)
- `CORS_ORIGIN` (`*` para pruebas, o una lista separada por coma)

> No subas el `SUPABASE_SERVICE_ROLE_KEY` a ningún lugar público.

---

## 3) Ejecutar el backend

En `backend/`:
```powershell
npm run dev
```

La API queda en:
`http://localhost:3000`

---

## 4) Deploy en Railway (produccion)

1. Crea un proyecto nuevo en Railway y conecta este repo/carpeta backend.
2. Railway detecta Node automaticamente y usa `npm start`.
3. En **Variables** agrega:
   - `SUPABASE_URL`
   - `SUPABASE_ANON_KEY`
   - `SUPABASE_SERVICE_ROLE_KEY`
   - `PROFESSIONAL_CARDS_BUCKET=professional_cards`
   - `CORS_ORIGIN=*` (o dominio web real)
4. Despliega y copia tu URL publica, por ejemplo:
   - `https://appmedicina-api.up.railway.app`
5. Verifica:
   - `GET https://TU_URL/health`

---

## 5) Endpoints

### Register (multipart)
`POST /api/auth/register`

Campos (form-data):
- `role`: `"Paciente"` o `"Especialista"`
- `firstName`, `lastName`, `age`, `phone`, `email`, `password`
- `professionalTitle` (Especialista)
- `specialty` (Especialista)
- `professionalCard` (archivo, Especialista, optional)

### Login (json)
`POST /api/auth/login`
Body:
- `email`
- `password`

Devuelve:
- `access_token`
- `refresh_token`
- `user: { id, email }`

### Me (token)
`GET /api/profile/me`
Header:
- `Authorization: Bearer <access_token>`

Devuelve:
- `profile`

---

## 6) Flutter apuntando a Railway

Ya esta conectado en el codigo con `API_BASE_URL`.
Ejemplos:

```powershell
flutter run --dart-define=API_BASE_URL=https://TU_URL_PUBLICA
```

Para Android emulator local:

```powershell
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:3000
```

