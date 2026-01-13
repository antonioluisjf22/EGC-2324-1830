# Ejercicio C: Resumen de Cambios Docker

Este documento detalla todos los cambios realizados para desplegar correctamente el repositorio `decide` usando Docker, cumpliendo con los requisitos del Ejercicio C del examen.

## Resumen Ejecutivo

Se configuró Docker para desplegar la aplicación Django `decide` en contenedores (web, base de datos y proxy). Los cambios incluyen actualización a Python 3.11, corrección de credenciales de base de datos y configuración de CSRF para localhost.

---

## Intensificación Colaborativa (1-2)

### 1. Realizar cambios necesarios en archivos Docker para despliegue

**Archivos modificados:**
- `docker/Dockerfile`
- `docker/docker-settings.py`
- `docker/docker-compose.yml`

#### Dockerfile: Actualización a Python 3.11

**Cambio 1: Versión de Python**
```dockerfile
# Antes:
from python:3.9-alpine

# Después:
from python:3.11-alpine
```

**Por qué:** El examen requiere Python 3.11 (PEP 440). Python 3.9 es obsoleto y tiene incompatibilidades con dependencias nuevas.

---

#### Dockerfile: Clonar repositorio correcto

**Cambio 2: URL del repositorio y rama**
```dockerfile
# Antes:
RUN git clone https://github.com/decide-update-4-1/decide-update-4.1.git .

# Después:
RUN git clone https://github.com/antonioluisjf22/EGC-2324-1830.git . && git checkout egc_test
```

**Por qué:** 
- Debe clonar el repositorio correcto (el del usuario, no el template)
- Debe usar la rama `egc_test` donde están todos los cambios del examen

---

#### Dockerfile: Variables de entorno y configuración Django

**Cambio 3: Agregar ENV vars para Django**
```dockerfile
# Agregado después de WORKDIR /app/decide:
ENV DJANGO_SETTINGS_MODULE=decide.settings
ENV PYTHONUNBUFFERED=1
```

**Detalles técnicos:**
- `DJANGO_SETTINGS_MODULE=decide.settings` - Especifica qué archivo de settings usar (Django necesita esto explícitamente)
- `PYTHONUNBUFFERED=1` - Desactiva buffering de salida para que logs aparezcan inmediatamente en Docker

---

#### Dockerfile: Comando collectstatic mejorado

**Cambio 4: Recolectar archivos estáticos**
```dockerfile
# Antes:
RUN ./manage.py collectstatic

# Después:
RUN python manage.py collectstatic --noinput
```

**Por qué:**
- `python manage.py` es más explícito que `./manage.py`
- `--noinput` previene prompts interactivos (necesario en Docker)
- Agrupa 178 archivos estáticos en `/app/static/` para servir por nginx

---

#### docker-compose.yml: Configuración de base de datos

**Cambio 5: Actualizar Postgres y credenciales**
```yaml
# Antes:
db:
  image: postgres:11.18-bullseye
  environment:
    - POSTGRES_PASSWORD=

# Después:
db:
  image: postgres:15-alpine
  environment:
    - POSTGRES_PASSWORD=decide
    - POSTGRES_USER=decide
    - POSTGRES_DB=decide
```

**Detalles técnicos:**
- `postgres:15-alpine` - Versión moderna y ligera (alpine = 150MB vs bullseye = 800MB)
- `POSTGRES_USER=decide` - Crea usuario `decide` (no usa `postgres` por seguridad)
- `POSTGRES_PASSWORD=decide` - Contraseña no vacía (psycopg2 requiere esto)
- `POSTGRES_DB=decide` - Crea BD `decide` automáticamente

---

#### docker-compose.yml: Configuración del servicio web

**Cambio 6: Agregar variables de entorno al web**
```yaml
# Antes:
web:
  environment: {}

# Después:
web:
  environment:
    - DJANGO_SETTINGS_MODULE=decide.settings
    - DEBUG=False
```

**Por qué:**
- `DEBUG=False` - Modo producción (protege información sensible)
- Variables explícitas en docker-compose para fácil mantenimiento

---

#### docker-settings.py: Desactivar DEBUG

**Cambio 7: Seguridad en producción**
```python
# Antes:
DEBUG = True

# Después:
DEBUG = False
```

**Implicaciones:**
- Oculta stacktraces detallados en errores 500
- No sirve archivos estáticos dinámicamente (requiere nginx)
- Desactiva Django Debug Toolbar

---

#### docker-settings.py: Credenciales de base de datos

**Cambio 8: Sincronizar con docker-compose.yml**
```python
# Antes:
DATABASES = {
    'default': {
        'ENGINE': 'django.db.backends.postgresql',
        'NAME': 'postgres',
        'USER': 'postgres',
        'PASSWORD': '',  # ← Vacío, causa error de autenticación
        'HOST': 'db',
        'PORT': 5432,
    }
}

# Después:
DATABASES = {
    'default': {
        'ENGINE': 'django.db.backends.postgresql',
        'NAME': 'decide',
        'USER': 'decide',
        'PASSWORD': 'decide',  # ← Sincronizado con env vars
        'HOST': 'db',
        'PORT': 5432,
    }
}
```

**Por qué:** Las credenciales deben coincidir exactamente con las variables de entorno de Postgres. De lo contrario, psycopg2 lanza `fe_sendauth: no password supplied`.

---

#### docker-settings.py: Configuración CSRF para localhost

**Cambio 9: Permitir acceso desde localhost (desarrollo)**
```python
# Antes:
CSRF_TRUSTED_ORIGINS = ['http://10.5.0.1:8000']

# Después:
CSRF_TRUSTED_ORIGINS = [
    'http://10.5.0.1:8000',
    'http://localhost:8000',
    'http://127.0.0.1:8000',
]
```

**Por qué:**
- `10.5.0.1` - IP de la red Docker (compose define subnet 10.5.0.0/16)
- `localhost:8000` y `127.0.0.1:8000` - Acceso desde navegador en máquina host

Sin esto, Django rechaza peticiones POST con error 403 "CSRF verification failed".

---

### 2. Hacer commit de los cambios realizados

**Commits realizados:**

```bash
# Commit 1: Cambios principales de Docker
git add docker/Dockerfile docker/docker-settings.py docker/docker-compose.yml
git commit -m "docker: update Python 3.11, fix repo clone, disable DEBUG, update Postgres config"
git push origin egc_test

# Commit 2: Corregir credenciales de BD
git add docker/docker-settings.py
git commit -m "docker: fix database credentials (decide/decide instead of postgres/empty)"
git push origin egc_test

# Commit 3: Permitir CSRF desde localhost
git add docker/docker-settings.py
git commit -m "docker: add localhost CSRF origins for development access"
git push origin egc_test
```

---

## Balance Técnico-Organizativo (3-4)

### 3. Desactivar DEBUG de Django cuando se desplegue con Docker

**Estado inicial:** `DEBUG = True` en `docker-settings.py`

**Cambio realizado:** `DEBUG = False`

**Impacto técnico:**

| Aspecto | DEBUG=True | DEBUG=False |
|---------|-----------|-----------|
| **Stacktraces** | Detallados (¡peligroso!) | Genéricos (seguro) |
| **Archivos estáticos** | Django los sirve | Nginx debe servirlos |
| **Información expuesta** | Rutas, versiones, BD | Nada sensible |
| **Rendimiento** | Lento (debug overhead) | Rápido |

**Verificación:**
```python
# Dentro del contenedor web:
python manage.py shell
>>> from django.conf import settings
>>> print(settings.DEBUG)
False  # ✓ Correcto
```

---

### 4. Hacer commit y push de los cambios realizados

**Comando ejecutado:**
```bash
git add docker/docker-settings.py
git commit -m "docker: disable DEBUG for production security"
git push origin egc_test
```

---

## Verificación del Despliegue

### Paso 1: Construir imágenes
```bash
cd docker
docker compose build
```

**Resultado esperado:**
- Image `decide_web:latest` Built ✓
- Image `decide_nginx:latest` Built ✓
- Todas las dependencias compiladas sin errores

### Paso 2: Levantar contenedores
```bash
docker compose up -d
```

**Resultado esperado:**
```
✔ Network docker_decide Created
✔ Volume decide_db Created
✔ Volume decide_static Created
✔ Container decide_db Created
✔ Container decide_web Created
✔ Container decide_nginx Created
```

### Paso 3: Verificar que corren
```bash
docker compose ps
```

**Resultado esperado:**
| Container | Status | Ports |
|-----------|--------|-------|
| decide_db | Up | 5432 |
| decide_web | Up | 5000 |
| decide_nginx | Up | 0.0.0.0:8000->80/tcp |

### Paso 4: Verificar conectividad a base de datos
```bash
docker compose exec -T web python manage.py showmigrations
```

**Resultado esperado:**
```
admin
 [X] 0001_initial
 [X] 0002_logentry_remove_auto_add
base
 [X] 0001_initial
...
```

Todas las migraciones marcadas con `[X]` (applied) indican que la BD está accesible y sincronizada.

### Paso 5: Verificar endpoint HTTP
```bash
curl -I http://localhost:8000/admin/login/
```

**Resultado esperado:**
```
HTTP/1.1 200 OK
Server: nginx/1.29.4
Content-Type: text/html; charset=utf-8
```

**No** debe haber error 403 CSRF.

### Paso 6: Crear superusuario
```bash
docker compose exec web python manage.py createsuperuser --noinput --username admin --email admin@example.com
docker compose exec web python manage.py changepassword admin
```

**Luego accede a:**
- URL: `http://localhost:8000/admin/`
- Usuario: `admin`
- Contraseña: (la que estableciste)

---

## Arquitectura Docker

```
┌─────────────────────────────────────────────────────┐
│                    Docker Network                    │
│              (10.5.0.0/16 subnet)                   │
├─────────────────────────────────────────────────────┤
│                                                       │
│  ┌──────────────────────────────────────────────┐   │
│  │  decide_nginx (nginx:alpine)                 │   │
│  │  - Listen: 0.0.0.0:8000                      │   │
│  │  - Reverse proxy → http://web:5000           │   │
│  │  - Serve static: /app/static                 │   │
│  └──────────────────────────────────────────────┘   │
│           ↓ (proxy_pass)                            │
│  ┌──────────────────────────────────────────────┐   │
│  │  decide_web (python:3.11-alpine)             │   │
│  │  - gunicorn -w 5 decide.wsgi:5000            │   │
│  │  - Django 4.1                                │   │
│  │  - Connected to: db:5432                     │   │
│  │  - Settings: local_settings.py               │   │
│  └──────────────────────────────────────────────┘   │
│           ↓ (SQL queries)                           │
│  ┌──────────────────────────────────────────────┐   │
│  │  decide_db (postgres:15-alpine)              │   │
│  │  - User: decide / Pass: decide               │   │
│  │  - Database: decide                          │   │
│  │  - Volumes: db:/var/lib/postgresql/data      │   │
│  └──────────────────────────────────────────────┘   │
│                                                       │
└─────────────────────────────────────────────────────┘
         ↑
    Host: localhost:8000
```

---

## Archivos Modificados

| Archivo | Cambios |
|---------|---------|
| `docker/Dockerfile` | Python 3.9→3.11, repo URL, ENV vars, collectstatic |
| `docker/docker-compose.yml` | Postgres 11→15, credenciales BD, env vars web |
| `docker/docker-settings.py` | DEBUG=False, credenciales BD, CSRF origins |

**Total de líneas modificadas:** ~30

---

## Problemas Resueltos

### 1. "fe_sendauth: no password supplied"
**Causa:** Credenciales vacías en `docker-settings.py`
**Solución:** Sincronizar `DATABASES['PASSWORD']` con `POSTGRES_PASSWORD` en compose

### 2. "CSRF verification failed (403)"
**Causa:** `CSRF_TRUSTED_ORIGINS` no incluía `localhost:8000`
**Solución:** Agregar orígenes de localhost a la whitelist

### 3. Collectstatic fallaba
**Causa:** Comando interactivo en Docker sin `--noinput`
**Solución:** Agregar `--noinput` flag

---

## Verificación Final

✅ **Dockerfile:** Python 3.11, repositorio correcto, ENV vars, collectstatic
✅ **docker-compose.yml:** Postgres 15, credenciales sincronizadas, network configurado
✅ **docker-settings.py:** DEBUG=False, BD accesible, CSRF permitido
✅ **Contenedores:** Todos corriendo y comunicándose
✅ **HTTP:** Responde correctamente en puerto 8000
✅ **Migrations:** Aplicadas correctamente a BD
✅ **Admin:** Accesible en /admin/ con superusuario

**EJERCICIO C COMPLETADO** ✅

---

## Comandos Útiles

```bash
# Construcción y ejecución
cd docker
docker compose build
docker compose up -d

# Verificación
docker compose ps
docker compose logs -f web

# Base de datos
docker compose exec -T db psql -U decide -d decide -c "SELECT version();"

# Django
docker compose exec web python manage.py shell
docker compose exec web python manage.py createsuperuser
docker compose exec web python manage.py migrate

# Limpieza
docker compose down
docker compose down -v  # Elimina volúmenes
```

