# Dónde va cada cosa (Supabase + Render + app)

## Las tres “cajas” (no es un solo archivo)

| Lugar | Qué es | Qué pegas ahí |
|--------|--------|----------------|
| **`backend/.env`** | Solo tu PC (desarrollo). **No** se sube a Git. | `DATABASE_URL`, `JWT_SECRET`, `PORT`, etc. |
| **Render → Web Service → Environment** | El servidor Node **encendido en la nube** (API 24/7 en plan free con posible sueño). | Las **mismas** claves que en `.env`: sobre todo `DATABASE_URL` y `JWT_SECRET`. |
| **Supabase → Edge Functions → Secrets** | Secreto para la función **`mediconnect`** (proxy). **No** es la base de datos. | Solo **`API_UPSTREAM`** = URL HTTPS de Render, ej. `https://appmedicina-api.onrender.com` (sin `/` al final). |

La app Flutter **no** lee `.env`: usa por código la URL  
`https://<tu-ref>.supabase.co/functions/v1/mediconnect`  
(o `--dart-define=API_BASE_URL=...` si quieres otro destino).

---

## Orden recomendado (checklist)

1. **Supabase → Database**  
   - Copia la **URI** de Postgres → será tu `DATABASE_URL`.  
   - Si la contraseña tiene `#`, `@`, etc., **codifícala en la URL** (ej. `#` → `%23`).

2. **`backend/.env`** (copia desde `.env.example` y rellena)  
   - Pega `DATABASE_URL` y pon un `JWT_SECRET` largo.  
   - En terminal (**PowerShell**): primero entra a la carpeta del repo `AppMedicina`, luego:
     - `cd backend`  ← carpeta **real** del proyecto; **no** uses texto tipo `ruta\a\...` (eso era solo un ejemplo en alguna guía).
     - `npm install`
     - `npm run dev`
   - Si ya estás en `...\AppMedicina\backend`, solo ejecuta `npm install` y `npm run dev`.
   - Prueba: `http://localhost:3000/health`

3. **Git**  
   - Push del repo (con `render.yaml` en la raíz si usas Blueprint).

4. **Render → New → Blueprint**  
   - Conecta el repo; crea `appmedicina-api`.  
   - En el servicio → **Environment**: añade **`DATABASE_URL`** (igual que en `.env`) y revisa **`JWT_SECRET`**.  
   - Espera el deploy y copia la URL, ej. `https://appmedicina-api.onrender.com`.  
   - Prueba: `https://ESA-URL/health`

5. **Supabase → Edge Functions → Secrets**  
   - Clave: **`API_UPSTREAM`**  
   - Valor: la URL de Render del paso 4 (sin `/` final).  
   - Redeploy de la función **`mediconnect`** si hace falta.  
   - Prueba: `https://TU_REF.supabase.co/functions/v1/mediconnect/health`

---

## Resumen mental

- **Supabase** = base de datos Postgres **+** (opcional) proxy HTTP hacia Render.  
- **Render** = proceso **Node** que es tu API real y debe tener **`DATABASE_URL`**.  
- **`.env`** = solo para correr Node **en tu máquina**.

---

## Si algo falla

- **503** en `/functions/v1/mediconnect/...` → falta o está mal **`API_UPSTREAM`**.  
- **Error Postgres** en Render → **`DATABASE_URL`** mal copiada o contraseña con caracteres sin codificar.  
- **Solo desarrollo local** → usa en Flutter:  
  `--dart-define=API_BASE_URL=http://10.0.2.2:3000`
