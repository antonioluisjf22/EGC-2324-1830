# Verificación del Despliegue en Render

## Requisitos Previos

Para verificar el despliegue en Render, necesitas:

1. **Cuenta en Render.com**
   - Accede a https://render.com
   - Registra una cuenta (puede ser con GitHub)

2. **Repositorio en GitHub conectado**
   - Tu repositorio debe ser público o estar conectado a Render
   - La rama `egc_test` debe estar disponible

3. **Variables de entorno configuradas en Render**
   - `SECRET_KEY` - Clave secreta de Django
   - `DEBUG` - false (ya configurado en render.yaml)
   - `DJANGO_SETTINGS_MODULE` - decide.settings (ya configurado)

---

## Pasos para Verificar en Render

### Paso 1: Crear un Web Service en Render

1. **Accede a Render Dashboard**
   - Ve a https://dashboard.render.com

2. **Crear nuevo servicio**
   - Click en "+ New" → "Web Service"
   - Selecciona "Build and deploy from a Git repository"

3. **Conectar repositorio**
   - Selecciona tu repositorio GitHub: `antonioluisjf22/EGC-2324-1830`
   - Selecciona rama: `egc_test`

4. **Configurar servicio**
   - **Name:** decide
   - **Region:** Oregon (u otra)
   - **Branch:** egc_test
   - **Build Command:** `bash build.sh` (automático desde render.yaml)
   - **Start Command:** `cd decide && gunicorn -w 4 --bind 0.0.0.0:$PORT decide.wsgi:application`
   - **Plan:** Free (o Starter según presupuesto)
   - **Python Version:** 3.11

### Paso 2: Conectar Base de Datos

1. **En el mismo formulario, bajo "Database"**
   - Render detectará `postgres` en render.yaml automáticamente
   - Click en "+ Add Database"
   - **Name:** decide_db
   - **Database:** PostgreSQL
   - **Region:** Oregon (mismo que web)
   - **Plan:** Free

2. **Render crea automáticamente:**
   - Usuario: `postgres`
   - Password: generada automáticamente
   - Database: `decide`

### Paso 3: Configurar Variables de Entorno

En la sección "Environment" del Web Service:

```
DEBUG=false
DJANGO_SETTINGS_MODULE=decide.settings
ALLOWED_HOSTS=decide-app.onrender.com,localhost
SECRET_KEY=<generar una contraseña fuerte>
```

Render proporciona automáticamente:
- `DATABASE_URL` (conexión a la BD PostgreSQL)
- `RENDER_EXTERNAL_URL` (URL pública del servicio)

### Paso 4: Deploy Inicial

1. **Click en "Create Web Service"**
   - Render comienza el proceso de build
   - Ver logs en tiempo real en la pestaña "Logs"

2. **Monitorear el build**
   - Fase 1: `pip install -r requirements.txt` (2-3 min)
   - Fase 2: `bash build.sh` ejecuta:
     - collectstatic (recopila archivos estáticos)
     - migrate (aplica migraciones)
     - crea usuario admin
   - Fase 3: Inicia gunicorn

### Paso 5: Verificación Post-Deploy

Una vez completado el deploy (debe mostrar "Your service is live"):

#### 1. **Verificar HTTP Status**
```bash
curl -I https://decide-app.onrender.com/
```

**Respuesta esperada:**
```
HTTP/1.1 404 Not Found
```
(404 es normal para `/`, no hay rutas definidas en la raíz)

#### 2. **Acceder a Admin**
- URL: `https://decide-app.onrender.com/admin/`
- Usuario: `admin` (creado por build.sh)
- Contraseña: (ver logs de build para las credenciales)

#### 3. **Verificar API**
```bash
curl https://decide-app.onrender.com/api/authentication/login/
```

#### 4. **Ver Logs**
En Render Dashboard:
- Click en tu servicio "decide"
- Pestaña "Logs"
- Debe mostrar: `Starting gunicorn XX.X.X`

---

## Validaciones Locales (sin Render)

Puedes validar la configuración localmente:

### 1. **Verificar render.yaml**
```bash
# Sintaxis YAML correcta
python3 -c "import yaml; yaml.safe_load(open('render.yaml')); print('✓ Valid')"
```

### 2. **Verificar requirements.txt**
```bash
grep -E "Django|gunicorn|whitenoise|psycopg2|dj-database-url" requirements.txt
# Debe mostrar todas estas líneas
```

### 3. **Ejecutar build.sh localmente**
```bash
bash build.sh
# Debe completarse sin errores
```

### 4. **Simular ejecución de gunicorn**
```bash
cd decide
gunicorn --bind 0.0.0.0:8000 decide.wsgi:application --workers 4
# Accede a http://localhost:8000/admin/
```

---

## Problemas Comunes y Soluciones

### 1. "ERROR: Could not find a version that satisfies the requirement..."

**Causa:** Versión de paquete no disponible
**Solución:** 
```bash
# Verificar versiones en requirements.txt
pip index versions Django
# Actualizar si es necesario
```

### 2. "ModuleNotFoundError: No module named 'decide'"

**Causa:** settings.py no se carga correctamente
**Solución:**
- Verificar `DJANGO_SETTINGS_MODULE=decide.settings`
- En Render: verificar variables de entorno

### 3. "CSRF verification failed"

**Causa:** El dominio no está en `ALLOWED_HOSTS` o `CSRF_TRUSTED_ORIGINS`
**Solución:**
```bash
# En render.yaml o environment:
ALLOWED_HOSTS=decide-app.onrender.com,localhost
```

### 4. "Database connection refused"

**Causa:** `DATABASE_URL` no está configurada
**Solución:**
- Render configura automáticamente si hay BD en render.yaml
- Verificar en Render Dashboard que la BD está "Available"

---

## Monitoreo Continuo

Una vez deployed:

1. **Auto-redeployment**
   - Cada push a `egc_test` dispara automáticamente un nuevo deploy
   - Ver en Render Dashboard → "Deploys"

2. **Logs**
   - Ver en tiempo real en Render Dashboard
   - Buscar errores en la sección "Logs"

3. **Métricas**
   - CPU, memoria, requests
   - Ver en "Metrics" tab

4. **Health Checks**
   - Render pinga automáticamente el endpoint
   - Si falla 3 veces, marca como "Down"

---

## Archivos de Configuración

Todos los archivos necesarios para Render están en el repositorio:

| Archivo | Propósito |
|---------|-----------|
| `render.yaml` | Configuración principal de Render |
| `build.sh` | Script de build (migrations, staticfiles, etc) |
| `requirements.txt` | Dependencias Python |
| `decide/decide/settings.py` | Configuración Django (detecta RENDER automáticamente) |

---

## URLs Útiles

- Render Dashboard: https://dashboard.render.com
- Aplicación deployed: https://decide-app.onrender.com
- Admin: https://decide-app.onrender.com/admin/
- Documentación Render: https://render.com/docs

---

## Resumen de Verificación

✅ **render.yaml:** Válido y completo
✅ **build.sh:** Ejecuta migrations y collectstatic
✅ **requirements.txt:** Incluye gunicorn, whitenoise, psycopg2, dj-database-url
✅ **Settings:** DEBUG=False, ALLOWED_HOSTS configurado
✅ **Variables de entorno:** Configurables en Render Dashboard
✅ **Base de datos:** PostgreSQL 15 (libre en Render)
✅ **Static files:** Servidos por whitenoise
✅ **WSGI:** gunicorn listo para producción

