# Docker — KDS Kitchen Display System

Guía completa para levantar el proyecto con Docker.

---

## Estructura de archivos

```
Kitchen-Display-System---KDS/
├── Makefile                        ← Todos los comandos desde aquí
├── docker-compose.yml              ← Stack de desarrollo
├── docker-compose.prod.yml         ← Stack de producción
├── .env.example                    ← Variables raíz (copiar a .env)
│
├── Backend/
│   ├── Dockerfile                  ← Multi-stage: development | production
│   ├── .dockerignore
│   ├── .env                        ← Variables de desarrollo (gitignored)
│   ├── .env.production             ← Variables de producción (gitignored)
│   ├── .env.development.example    ← Plantilla de desarrollo
│   └── .env.production.example     ← Plantilla de producción
│
└── Frontend/kds/
    ├── Dockerfile                  ← Build Flutter web → serve nginx
    ├── .dockerignore
    └── nginx.conf                  ← Config nginx SPA
```

---

## Primeros pasos

### 1. Configurar variables de entorno

**Desarrollo:**
```bash
cp Backend/.env.development.example Backend/.env
# Editar Backend/.env con tus keys de Supabase dev
```

**Producción:**
```bash
cp Backend/.env.production.example Backend/.env.production
cp .env.example .env
# Editar ambos archivos con keys reales y URL pública
```

### 2. Arrancar desarrollo

```bash
make up
```

| Servicio   | URL                          |
|------------|------------------------------|
| Frontend   | http://localhost:3000        |
| Backend    | http://localhost:8000        |
| API Docs   | http://localhost:8000/docs   |

### 3. Arrancar producción

```bash
make prod-up
```

| Servicio   | URL                          |
|------------|------------------------------|
| Frontend   | http://localhost:80          |
| Backend    | http://localhost:8000        |

---

## Referencia de comandos

Ejecutar `make help` para ver todos los targets. Los más usados:

### Ciclo de vida

| Comando          | Descripción                                      |
|------------------|--------------------------------------------------|
| `make up`        | Arrancar desarrollo (detached)                   |
| `make down`      | Detener y eliminar contenedores                  |
| `make rebuild`   | Reconstruir imágenes y arrancar                  |
| `make restart`   | Reiniciar todos los servicios                    |
| `make stop`      | Pausar sin eliminar                              |
| `make start`     | Reanudar contenedores pausados                   |

### Logs y diagnóstico

| Comando               | Descripción                         |
|-----------------------|-------------------------------------|
| `make logs`           | Todos los logs en tiempo real       |
| `make logs-backend`   | Solo logs del backend               |
| `make logs-frontend`  | Solo logs del frontend (nginx)      |
| `make ps`             | Estado de los contenedores          |
| `make stats`          | Uso de CPU/RAM en tiempo real       |
| `make health`         | Consultar /health del backend       |

### Desarrollo

| Comando               | Descripción                                     |
|-----------------------|-------------------------------------------------|
| `make shell-backend`  | Shell bash dentro del backend                   |
| `make lint`           | Ruff check — análisis estático Python           |
| `make format`         | Ruff format — formateo Python                   |
| `make typecheck`      | Mypy — verificación de tipos                    |
| `make test`           | Pytest                                          |
| `make test-coverage`  | Pytest con reporte de cobertura                 |
| `make flutter-rebuild`| Reconstruir solo la imagen del frontend         |

### Producción

| Comando              | Descripción                               |
|----------------------|-------------------------------------------|
| `make prod-up`       | Arrancar producción                       |
| `make prod-down`     | Detener producción                        |
| `make prod-rebuild`  | Reconstruir y arrancar producción         |
| `make prod-logs`     | Logs de producción en tiempo real         |
| `make prod-health`   | Health check de producción                |

### Limpieza

| Comando       | Descripción                                          |
|---------------|------------------------------------------------------|
| `make clean`  | Eliminar contenedores, redes y volúmenes (con aviso) |
| `make prune`  | `docker system prune` — liberar espacio en disco     |

---

## Hot reload del backend

El backend monta `./Backend/app` como volumen dentro del contenedor.
Uvicorn observa cambios en ese directorio y recarga automáticamente.

**Cambios que SÍ recargan solos:**
- Cualquier archivo `.py` dentro de `Backend/app/`

**Cambios que requieren `make rebuild`:**
- `Backend/Pyproject.toml` (nuevas dependencias)
- `Backend/Dockerfile`
- Variables de entorno en `Backend/.env`

---

## Actualizar dependencias Python

```bash
# 1. Agregar la dependencia a Backend/Pyproject.toml
# 2. Reconstruir la imagen
make rebuild
```

---

## Actualizar dependencias Flutter

```bash
# 1. Editar Frontend/kds/pubspec.yaml
# 2. Reconstruir solo el frontend
make flutter-rebuild
```

---

## Configuración de la URL del backend en el frontend

El frontend Flutter se compila con la URL del backend baked en el JavaScript.
Esto significa que **cambiar la URL requiere reconstruir la imagen**.

- **Desarrollo:** `API_URL=http://localhost:8000` (hardcoded en `docker-compose.yml`)
- **Producción:** `API_URL=${PROD_API_URL}` — se lee desde `.env`

Para cambiar la URL en producción:
```bash
# Editar .env
PROD_API_URL=https://api.midominio.com

# Reconstruir
make prod-rebuild
```

En el código Dart acceder a la URL así:
```dart
const String apiUrl = String.fromEnvironment(
  'API_URL',
  defaultValue: 'http://localhost:8000',
);
```

---

## Notas de seguridad

- `Backend/.env` y `Backend/.env.production` están en `.gitignore` — **nunca subirlos a git**
- La imagen de producción del backend **no contiene** ningún archivo `.env`
- Las variables de entorno se inyectan en tiempo de ejecución por docker compose
- Los docs de la API (`/docs`, `/redoc`) están **desactivados** cuando `APP_ENV=production`
