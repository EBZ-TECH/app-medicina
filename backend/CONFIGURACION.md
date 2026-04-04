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

## Paso 4 detallado: Render (API en internet con Blueprint)

Este flujo usa el archivo **`render.yaml`** en la **raíz** del repo (no dentro de `backend/`). Render lee ese YAML y crea un **Web Service** llamado **`appmedicina-api`**: Node 20, carpeta de trabajo `backend`, `npm install` + `npm start`.

### 4.0 Antes de abrir Render

1. Tu backend debe funcionar en local (`http://localhost:3000/health` con `DATABASE_URL` y `JWT_SECRET` en `backend/.env`).
2. El proyecto **AppMedicina** debe estar en **GitHub, GitLab o Bitbucket** (Render se conecta al repo remoto, no a tu carpeta de OneDrive sola).
3. En la **raíz** del repo (junto a `pubspec.yaml` de Flutter) debe existir **`render.yaml`**. Haz **commit** y **push** para que Render vea el archivo.

### 4.1 Cuenta y acceso a Git

1. Entra en [https://render.com](https://render.com) y crea cuenta o inicia sesión (puedes usar **Sign in with GitHub**).
2. La primera vez, Render pedirá **autorización** para leer tus repositorios. Acepta al menos el repo **AppMedicina** (o “All repositories” si te parece bien).

### 4.2 Crear el despliegue desde el Blueprint

1. En el [Dashboard de Render](https://dashboard.render.com), arriba a la derecha pulsa **New +** (o **New**).
2. Elige **Blueprint** (a veces aparece como *Deploy from blueprint* o dentro de “Infrastructure as code”).
3. Si te pide conectar GitHub/GitLab otra vez, hazlo.
4. **Selecciona el repositorio** donde está AppMedicina y la **rama** (normalmente `main` o `master`).
5. Render detecta **`render.yaml`** y muestra un resumen: debería aparecer **un servicio web** `appmedicina-api` (runtime Node, root directory `backend`).
6. Pulsa **Apply** / **Connect** / **Deploy** (el botón final que confirme crear los recursos).

### 4.3 Variables de entorno (muy importante)

En `render.yaml`, **`DATABASE_URL`** está con `sync: false`: Render **no** puede inventar esa cadena; **tú debes ponerla** en el panel.

1. Cuando termine el asistente, en el dashboard entra al servicio **`appmedicina-api`** (icono de web, no Postgres).
2. En el menú del servicio, abre **Environment** (Variables de entorno).
3. Busca **`DATABASE_URL`**:
   - Si **no existe**, pulsa **Add Environment Variable**, nombre exacto `DATABASE_URL`, valor = la **misma URI** que usas en `backend/.env` (Supabase). Sin espacios antes/después. Marca como **secret** si Render lo ofrece.
   - Si **ya existe** vacía o incorrecta, edítala y pega el valor bueno.
4. Revisa **`JWT_SECRET`**:
   - El blueprint puede haber **generado** una automáticamente (`generateValue: true`). Esa vale para producción en Render, pero será **distinta** a la de tu PC: los tokens de login **no** servirán entre local y nube.
   - Para no liarte al principio, puedes **sustituir** `JWT_SECRET` en Render por **el mismo valor** que tienes en `backend/.env` (así pruebas igual en ambos sitios). Más adelante puedes separar secretos por entorno.
5. Comprueba que existan (suelen venir del YAML): **`PORT`** = `3000`, **`CORS_ORIGIN`** = `*`, **`NODE_VERSION`** = `20`.
6. Pulsa **Save Changes** (Guardar).

### 4.4 Desplegar de nuevo

1. Tras cambiar variables, ve a la pestaña **Manual Deploy** → **Deploy latest commit** (o **Clear build cache & deploy** si un deploy anterior falló por caché rara).
2. Abre **Logs** (registros) y espera a ver algo como `Your service is live` o que el build termine sin error rojo.
3. El **primer deploy** puede tardar **5–15 minutos** (instala dependencias npm).

### 4.5 URL pública y prueba

1. En la parte superior del servicio verás la URL, por ejemplo **`https://appmedicina-api.onrender.com`** (el nombre exacto depende del campo **name** en `render.yaml`: `appmedicina-api`).
2. Abre en el navegador: `https://TU-URL.onrender.com/health`  
   - Respuesta esperada: JSON con `"ok": true`.
3. **Plan gratuito:** si hace minutos que nadie usa la API, el servicio **se duerme**. La **primera** petición puede tardar **30–60 segundos** o más; las siguientes suelen ser rápidas. Eso es normal.

### 4.6 Si el build o el runtime fallan

- **Logs → Build:** mira si falló `npm install` (red, paquetes).
- **Logs → Runtime:** errores de Node al arrancar; lo típico es **`DATABASE_URL` vacía o incorrecta** o error SSL/conexión a Supabase.
- **Supabase pausado:** si el proyecto Supabase está inactivo, Postgres no acepta conexiones; reactívalo en el panel de Supabase.

### 4.7 Qué hacer con esa URL después

- Cópiala **sin** barra final y úsala en **Supabase** como secreto **`API_UPSTREAM`** (Paso 5 de la checklist).
- Opcional: en Flutter puedes probar directo con  
  `--dart-define=API_BASE_URL=https://appmedicina-api.onrender.com`  
  (sin pasar por la Edge Function).

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

### Render: “Deploy failed” / “Exited with status 1”

1. Abre el servicio → pestaña **Logs** (o el enlace **deploy logs** del correo) y mira la **última línea en rojo**. Suele decir `Failed to start: ...` o un error de `pg` / conexión.
2. **`DATABASE_URL` vacía en Render:** en **Environment** debe existir la variable (la misma URI que en `backend/.env`). Sin eso el proceso sale con código 1 al arrancar.
3. **IPv4 (muy frecuente):** si el log dice **`ENETUNREACH`** y una IP que empieza por **`2600:`** (IPv6), tu `DATABASE_URL` usa el host **directo** `db.xxx.supabase.co`, que en la práctica resuelve a IPv6. **Render no llega ahí.** Solución: en Supabase pulsa **Connect** → pestaña/método **Session pooler** (Session mode, puerto **5432**) → copia la URI (usuario suele ser `postgres.TU_REF`, host `aws-0-REGION.pooler.supabase.com`). Sustituye **`DATABASE_URL`** en **Render → Environment** y en **`backend/.env`**, guarda y vuelve a desplegar.
4. **Proyecto Supabase pausado:** reactívalo en el dashboard; si no, la conexión falla.
5. **Contraseña con símbolos:** en la URI deben ir **codificados** (`#` → `%23`, etc.).
