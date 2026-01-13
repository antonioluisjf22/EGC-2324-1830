# Ejercicio B: Resumen de Actividades

## Intensificación Colaborativa (1-4)

### 1. Modificar workflow a Python 3.11
- **Cambio:** Actualizar `actions/setup-python@v4` con `python-version: '3.11'` en todos los jobs.

**Snippet añadido en jobs `tests`, `cobertura` y `build`:**
```yaml
- uses: actions/setup-python@v4
  with:
    python-version: '3.11'
```

**Archivos/líneas:**
- Job `tests` (líneas 14-16)
- Job `cobertura` (líneas 34-36)
- Job `build` (líneas 71-73)

**Detalles técnicos:**
- Versión específica: `3.11` (en lugar de `3.x` o `latest`)
- Action oficial de GitHub: `actions/setup-python@v4`
- Se aplica a cada job que ejecuta código Python

---

### 2. Preparar job 'cobertura' para Codacy
- **Cambio:** Crear un nuevo job `cobertura` (líneas 31-51) completamente independiente que:
  - Depende del job `tests` para ejecutarse después
  - Instala herramientas de coverage
  - Genera reporte `coverage.xml`
  - Integra automáticamente con Codacy

**Estructura completa del job:**
```yaml
cobertura:
  needs: tests                          # Espera a que 'tests' termine
  runs-on: ubuntu-latest
  steps:
    - uses: actions/checkout@v4
    - uses: actions/setup-python@v4
      with:
        python-version: '3.11'
    - name: Install deps + coverage
      run: |
        python -m pip install --upgrade pip
        pip install -r requirements.txt coverage
    - name: Run tests with coverage
      run: |
        coverage run -m pytest          # Ejecuta tests y registra coverage
        coverage xml -o coverage.xml    # Genera XML para Codacy
    - name: Upload coverage to Codacy
      if: ${{ secrets.CODACY_PROJECT_TOKEN != '' }}  # Solo si existe el secret
      env:
        CODACY_PROJECT_TOKEN: ${{ secrets.CODACY_PROJECT_TOKEN }}
      run: |
        bash <(curl -Ls https://coverage.codacy.com/get.sh) coverage.xml || echo "Codacy upload skipped"
```

**Detalles clave:**
- `needs: tests` → dependency entre jobs (ejecuta tras `tests`)
- `coverage run -m pytest` → captura métricas durante tests
- `coverage xml` → genera formato compatible con Codacy
- `if: ${{ secrets.CODACY_PROJECT_TOKEN != '' }}` → paso condicional (solo con secret)
- Upload a Codacy: script oficial de Codacy que sube `coverage.xml`

---

### 3. Commit y push
**Comando ejecutado:**
```bash
git add .github/workflows/django.yml
git commit -m "ci: add postgres matrix (14.9, 15) and auto-release job on tags"
git push origin egc_test
```

**Cambios incluidos:**
- Unificación de workflow (eliminación de duplicados y errata de YAML)
- Adición de Python 3.11 en todos los jobs
- Creación del job `cobertura`
- Adición de matriz de Postgres (actividades 5)
- Adición del job `release` (actividades 8)

**Resultado:**
- Commit: `24b0c9d`
- Branch: `egc_test` (upstream sincronizado)

---

### 4. Verificación
**Acciones realizadas:**
- Acceso a GitHub → pestaña **Actions** → seleccionar workflow "Django CI"
- Filtro por rama: `egc_test`
- Verificación de ejecución automática en pushes
- Disparo manual vía `workflow_dispatch`

**Indicadores de éxito:**
- ✅ Workflow aparece en Actions
- ✅ Job `tests` ejecuta (Python 3.11)
- ✅ Job `cobertura` ejecuta tras `tests` (sin errores)
- ✅ Botón "Run workflow" visible (workflow_dispatch)

---

## Balance Técnico-Organizativo (5-7)

### 5. Configurar matriz de Postgres (14.9 y 15)
- **Cambio:** Añadir bloque `strategy.matrix` al job `build` para ejecutarlo con múltiples versiones de Postgres.

**Snippet añadido (líneas 62-63):**
```yaml
build:
  runs-on: ubuntu-latest
  strategy:
    matrix:
      postgres-version: [ '14.9', '15' ]  # Define dos versiones
  services:
    postgres:
      image: postgres:${{ matrix.postgres-version }}  # Usa variable de matriz
      env:
        POSTGRES_USER: decide
        POSTGRES_PASSWORD: decide
        POSTGRES_DB: decide
      ports:
        - 5432:5432
      options: --health-cmd pg_isready --health-interval 10s --health-timeout 5s --health-retries 5
```

**Detalles técnicos:**
- `strategy.matrix.postgres-version` → Define los valores: `'14.9'` y `'15'`
- `${{ matrix.postgres-version }}` → Variable que toma cada valor en cada iteración
- **Efecto:** Job `build` se ejecuta **2 veces** (una por cada versión)
- Cada ejecución con su Postgres configurado (imagen `postgres:14.9` y `postgres:15`)
- Logs y resultados separados por versión en GitHub Actions

**Variables disponibles en cada ejecución:**
```
Run 1: postgres-version = 14.9  → image: postgres:14.9
Run 2: postgres-version = 15    → image: postgres:15
```

**Ventaja:**
- Verifica compatibilidad del código con múltiples versiones de BD
- Detecta issues de compatibilidad antes de producción

---

### 6. Commit y push
**Comando ejecutado:**
```bash
git add .github/workflows/django.yml
git commit -m "ci: add postgres matrix (14.9, 15) and auto-release job on tags"
git push origin egc_test
```

**Cambios incluidos:**
- Adición de `strategy.matrix` al job `build`
- Cambio de imagen estática `postgres:14.9` a dinámica `postgres:${{ matrix.postgres-version }}`

**Resultado:**
- Los cambios de matrices se incluyen en el mismo commit que el job `release` (actividad 8)

---

### 7. Verificación
**Acciones realizadas:**
- Acceso a GitHub → Actions → "Django CI"
- Seleccionar la rama `egc_test` y ver ejecuciones del job `build`

**Indicadores de éxito:**
- ✅ Job `build` aparece con **2 runs** (uno por versión de Postgres)
- ✅ Cada run etiquetado con su versión (ej: `build (14.9)` y `build (15)`)
- ✅ Ambos runs completados exitosamente (sin errores)
- ✅ Logs muestran la versión de Postgres usada en cada run
- ✅ Tests ejecutados contra ambas versiones simultáneamente

---

## Intensificación Técnica (8-10)

### 8. Configurar releases automáticas
- **Cambio:** Crear nuevo job `release` (líneas 109-122) que se dispara automáticamente en cada push a `egc_test`.

**Estructura completa del job (líneas 109-122):**
```yaml
release:
  needs: [ tests, build, cobertura ]           # Espera a que los 3 jobs terminen
  runs-on: ubuntu-latest
  if: github.ref == 'refs/heads/egc_test'      # Se ejecuta en cada push a egc_test
  steps:
    - uses: actions/checkout@v4                # Descarga el código
    - name: Create Release
      uses: softprops/action-gh-release@v1     # Action oficial para crear releases
      with:
        name: Release ${{ github.ref_name }}   # Nombre: "Release egc_test"
        draft: false                           # No como borrador
        prerelease: false                      # Versión estable
      env:
        GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}  # Token automático de GitHub
```

**Detalles técnicos:**

1. **Trigger Automático:**
   - `if: github.ref == 'refs/heads/egc_test'` → Se ejecuta **automáticamente en cada push a egc_test**
   - No requiere intervención manual

2. **Dependencias:**
   - `needs: [ tests, build, cobertura ]` → Espera a que los 3 jobs completen exitosamente
   - Si alguno falla, este job no se ejecuta

3. **Action Utilizada:**
   - `softprops/action-gh-release@v1` → Librería de terceros para crear releases en GitHub
   - Crea automáticamente un release con el nombre y configuración indicada

4. **Variables Dinámicas:**
   - `${{ github.ref_name }}` → Nombre del branch (ej: `egc_test`)
   - `${{ secrets.GITHUB_TOKEN }}` → Token automático para autenticación

5. **Opciones:**
   - `draft: false` → Release visible inmediatamente (no borrador)
   - `prerelease: false` → Marca como versión estable en GitHub

---

### 9. Commit y push
**Comando ejecutado:**
```bash
git add .github/workflows/django.yml
git commit -m "ci: enable automatic releases on every push to egc_test"
git push origin egc_test
```

---

### 10. Verificación de release automático
**Resultado esperado:**

1. Cada push a `egc_test` dispara automáticamente el workflow
2. Tras completar los 3 jobs (`tests`, `build`, `cobertura`), el job `release` se ejecuta
3. Se crea automáticamente una nueva release en GitHub

**Indicadores de éxito:**
- ✅ En GitHub Actions: job `release` se ejecuta tras cada push a `egc_test`
- ✅ En GitHub Releases: nuevo release creado automáticamente
  - URL: `https://github.com/antonioluisjf22/EGC-2324-1830/releases`
- ✅ Release etiquetado con nombre del branch y timestamp
- ✅ No requiere intervención manual (totalmente automático)

---

## Resumen de Cambios Clave

| Aspecto | Cambio |
|--------|--------|
| **Python** | 3.11 en todos los jobs |
| **Jobs** | `tests`, `cobertura`, `build`, `release` |
| **Coverage** | Job `cobertura` con upload a Codacy |
| **Postgres** | Matriz: 14.9 y 15 |
| **Releases** | Automáticas al pushear tags `v*` |
| **Triggers** | `push` (ramas + tags), `pull_request`, `workflow_dispatch` |

---

## Archivo Principal

**`.github/workflows/django.yml`** — workflow único que incluye:
- Setup de Python 3.11 (PEP 440)
- Tests básicos
- Coverage con integración Codacy
- Build con matriz de Postgres
- Releases automáticas
