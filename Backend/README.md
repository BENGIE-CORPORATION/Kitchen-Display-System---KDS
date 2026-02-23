# KDS Backend — Guía de Desarrollo

## Stack

- **Python 3.11** — FastAPI + Uvicorn
- **Base de datos** — Supabase (PostgreSQL gestionado)
- **Autenticación** — Supabase Auth (JWT)
- **Versión** — `0.1.0` (fuente de verdad: `pyproject.toml`)

---

## Setup inicial

```bash
# 1. Entorno virtual
python -m venv venv
source venv/bin/activate        # Mac/Linux
# venv\Scripts\activate         # Windows

# 2. Instalar dependencias
pip install -e ".[dev]"

# 3. Variables de entorno
cp .env.example .env
# Editar .env con las credenciales reales
```

### Variables de entorno requeridas

```env
SUPABASE_URL=https://xxx.supabase.co
SUPABASE_KEY=eyJ...              # anon key — para queries normales
SUPABASE_SERVICE_KEY=eyJ...      # service_role key — para operaciones admin (invite, delete user)
SUPABASE_JWT_SECRET=...          # Settings → API → JWT Settings en Supabase Dashboard
SECRET_KEY=...                   # python -c "import secrets; print(secrets.token_hex(32))"
DEBUG=True
```

> `SUPABASE_SERVICE_KEY` se obtiene en Supabase Dashboard → Settings → API → `service_role`.
> Nunca exponerla en el frontend.

### Levantar el servidor

```bash
make run          # http://localhost:8000
make install-dev  # instalar/actualizar dependencias
make lint         # ruff check
make format       # ruff format
make test         # pytest
```

**Documentación interactiva:** `http://localhost:8000/docs`

---

## Arquitectura

```
Cliente HTTP
     ↓
Router  (app/api/v1/)        — solo lógica HTTP, sin SQL
     ↓
CRUD    (app/crud/)           — toda la lógica de Supabase
     ↓
Supabase Client (app/database.py)
     ↓
Supabase (PostgreSQL)
```

**Regla fundamental:** los routers no contienen queries. Todo acceso a datos va en la capa CRUD.

### Estructura de carpetas

```
app/
├── api/v1/                  # Routers — un archivo por recurso
│   ├── auth.py
│   ├── empresas.py
│   ├── sucursales.py
│   ├── perfiles.py
│   └── usuarios_sucursales.py
├── crud/                    # Lógica de base de datos
│   ├── crud_empresa.py
│   ├── crud_sucursales.py
│   ├── crud_perfiles_usuario.py
│   └── crud_usuarios_sucursales.py
├── schemas/                 # Validación Pydantic (entrada/salida HTTP)
│   ├── auth.py
│   ├── empresa.py
│   ├── sucursal.py
│   ├── perfil.py
│   └── usuario_sucursal.py
├── models/                  # Constantes: TABLE_NAME, columnas permitidas
│   ├── empresa.py
│   ├── sucursal.py
│   ├── perfil.py
│   └── usuario_sucursal.py
├── core/
│   ├── security.py          # Dependencias de autenticación
│   ├── pagination.py        # PaginatedResponse reutilizable
│   └── exceptions/
│       └── http_exceptions.py
├── config.py                # Settings (lee versión de pyproject.toml)
├── database.py              # Clientes Supabase (normal + admin)
└── main.py                  # App FastAPI, routers, CORS
```

---

## Clientes de Supabase

Hay **dos clientes** en `app/database.py`:

| Cliente | Función | Cuándo usarlo |
|---------|---------|---------------|
| `get_supabase()` | Queries normales (SELECT, INSERT, UPDATE) | La mayoría de endpoints |
| `get_supabase_admin()` | Operaciones de auth admin | `invite`, `delete_user`, revocar sesiones |

```python
# Uso en un router
def mi_endpoint(
    db: Annotated[Client, Depends(get_supabase)],
    db_admin: Annotated[Client, Depends(get_supabase_admin)],  # solo si necesitas auth.admin.*
):
```

`get_supabase_admin()` usa `SUPABASE_SERVICE_KEY`. Sin esta key las operaciones como crear usuarios dan `"User not allowed"`.

---

## Sistema de autenticación

### Flujo de tokens

```
Login → Supabase valida credenciales → retorna { access_token, refresh_token }
Cada request → Header: Authorization: Bearer <access_token>
Token expira (1h por defecto) → POST /auth/refresh con refresh_token → nuevo access_token
```

### Dependencias de seguridad (`app/core/security.py`)

Se inyectan con `Depends()` en los endpoints:

```python
get_current_user       # JWT válido + perfil activo en perfiles_usuario
get_current_admin      # rol_global = admin_empresa | super_admin
get_current_superadmin # rol_global = super_admin únicamente

verify_empresa_access(current_user, empresa_id)   # el recurso pertenece a tu empresa
verify_sucursal_access(db, current_user, sucursal_id)  # tienes asignación en esa sucursal
```

### Roles

| Rol | Acceso |
|-----|--------|
| `super_admin` | Todo el sistema, todas las empresas |
| `admin_empresa` | Todo lo de su empresa (sucursales, perfiles, asignaciones) |
| `empleado` | Solo sus sucursales asignadas en `usuarios_sucursales` |

### Tablas de Supabase Auth

```
auth.users (Supabase — NO tocar directamente)
     ↕ mismo UUID
public.perfiles_usuario (tuya — aquí viven rol, empresa, estado)
```

---

## Modelos de datos

### Tablas en Supabase

```
empresas
  └── sucursales (empresa_id FK)
        └── usuarios_sucursales (sucursal_id FK)
              └── perfiles_usuario (usuario_id FK → auth.users)
```

### Estados válidos

| Tabla | Estados |
|-------|---------|
| `empresas` | `activo` · `suspendido` · `inactivo` |
| `sucursales` | `activo` · `inactivo` · `mantenimiento` |
| `perfiles_usuario` | `activo` · `inactivo` · `suspendido` |
| `usuarios_sucursales` | `activo` · `inactivo` |

**Soft delete:** ninguna tabla se borra físicamente. El estado `inactivo` es el delete lógico. Los endpoints `DELETE /recurso/{id}/hard` hacen borrado físico y son exclusivos de `super_admin`.

---

## Endpoints

Todos bajo `/api/v1/`. Requieren `Authorization: Bearer <token>` salvo `/auth/login` y `/auth/refresh`.

### Auth `/auth`

| Método | Ruta | Acceso | Descripción |
|--------|------|--------|-------------|
| POST | `/login` | Público | Retorna access_token + refresh_token |
| POST | `/refresh` | Público | Renueva el access_token |
| POST | `/register` | Público | Crea admin_empresa + perfil |
| GET | `/me` | Autenticado | Perfil propio + sucursales asignadas |
| POST | `/logout` | Autenticado | Invalida sesión |
| POST | `/invite` | admin_empresa · super_admin | Crea empleado con contraseña temporal |

> `/invite` retorna `password_temporal` en la respuesta. El admin la comparte al empleado de forma segura fuera del sistema.

### Empresas `/empresas`

| Método | Ruta | Acceso |
|--------|------|--------|
| GET | `/` | Autenticado (filtra por empresa propia) |
| GET | `/{id}` | Autenticado + misma empresa |
| POST | `/` | super_admin |
| PATCH | `/{id}` | admin_empresa · super_admin |
| DELETE | `/{id}` | admin_empresa · super_admin (soft) |
| DELETE | `/{id}/hard` | super_admin |

### Sucursales `/sucursales`

| Método | Ruta | Acceso |
|--------|------|--------|
| GET | `/` | Autenticado (filtra por empresa propia) |
| GET | `/empresa/{empresa_id}` | Autenticado + misma empresa |
| GET | `/{id}` | Autenticado + acceso a esa sucursal |
| POST | `/` | admin_empresa · super_admin |
| PATCH | `/{id}` | admin_empresa · super_admin |
| DELETE | `/{id}` | admin_empresa · super_admin (soft) |
| DELETE | `/{id}/hard` | super_admin |

### Perfiles `/perfiles`

| Método | Ruta | Acceso |
|--------|------|--------|
| GET | `/me` | Autenticado (propio perfil) |
| PATCH | `/me` | Autenticado (solo nombre, teléfono, avatar) |
| GET | `/` | admin_empresa · super_admin |
| GET | `/empresa/{empresa_id}` | admin_empresa · super_admin |
| GET | `/{id}` | admin_empresa · super_admin |
| PATCH | `/{id}/rol` | super_admin |
| PATCH | `/{id}/estado` | admin_empresa · super_admin |
| DELETE | `/{id}` | admin_empresa · super_admin (soft) |
| DELETE | `/{id}/hard` | super_admin |

### Usuarios × Sucursales `/usuarios-sucursales`

| Método | Ruta | Acceso |
|--------|------|--------|
| GET | `/sucursal/{id}` | admin_empresa · super_admin |
| GET | `/usuario/{id}` | Propio usuario · admin · super_admin |
| POST | `/` | admin_empresa · super_admin |
| PATCH | `/{id}` | admin_empresa · super_admin |
| DELETE | `/{id}` | admin_empresa · super_admin (soft) |
| DELETE | `/{id}/hard` | admin_empresa · super_admin |

---

## Sincronizaciones críticas

Estas operaciones tienen efectos en cascada que el CRUD maneja automáticamente:

| Operación | Efecto en cascada |
|-----------|------------------|
| Soft delete de **sucursal** | Desactiva todas las asignaciones `usuarios_sucursales` de esa sucursal |
| Hard delete de **sucursal** | Elimina asignaciones primero (FK constraint) |
| Soft delete de **perfil** | Desactiva asignaciones + revoca sesiones activas en Supabase Auth |
| Hard delete de **perfil** | Elimina asignaciones → perfil → `auth.users` en ese orden |
| Desactivar **asignación principal** | Promueve automáticamente la siguiente asignación activa como principal |
| Crear **primer invite** | La primera sucursal asignada se marca automáticamente como `es_principal = true` |

---

## Crear un nuevo módulo

Seguir este orden:

```
1. app/models/mi_recurso.py       → TABLE_NAME, SORTABLE_COLUMNS
2. app/schemas/mi_recurso.py      → Base, Read, Create, CreateInternal, Update, UpdateInternal
3. app/crud/crud_mi_recurso.py    → exists, create, get, get_multi, update, soft_delete, hard_delete
4. app/api/v1/mi_recurso.py       → router con Depends de seguridad apropiados
5. app/api/v1/__init__.py         → include_router(mi_recurso_router)
```

### Skeleton mínimo de un CRUD

```python
# app/crud/crud_mi_recurso.py
from ..models.mi_recurso import TABLE_NAME

def get_mi_recurso(db: Client, recurso_id: UUID) -> dict | None:
    result = db.table(TABLE_NAME).select("*").eq("id", str(recurso_id)).limit(1).execute()
    return result.data[0] if result.data else None

def create_mi_recurso(db: Client, data: MiRecursoCreateInternal) -> dict:
    result = db.table(TABLE_NAME).insert(data.model_dump()).execute()
    return result.data[0]
```

### Skeleton mínimo de un router

```python
# app/api/v1/mi_recurso.py
from ...core.security import get_current_user, get_current_admin

router = APIRouter(prefix="/mi-recurso", tags=["Mi Recurso"])

@router.get("/{id}", response_model=MiRecursoRead)
def read_mi_recurso(
    id: UUID,
    db: Annotated[Client, Depends(get_supabase)],
    current_user: Annotated[dict, Depends(get_current_user)],  # 🔒
) -> dict:
    recurso = get_mi_recurso(db, id)
    if not recurso:
        raise NotFoundException("Recurso no encontrado")
    return recurso
```

---

## Gestión de versiones

La versión vive **únicamente** en `pyproject.toml`:

```toml
[project]
version = "0.2.0"
```

`app/config.py` la lee automáticamente. No hay que cambiarla en ningún otro lugar.

---

## Pendiente / Próximos pasos

- [ ] Row Level Security (RLS) en Supabase — actualmente deshabilitado para desarrollo
- [ ] Rate limiting con `slowapi`
- [ ] Logging estructurado con `loguru`
- [ ] Conversión a `async def` en todos los endpoints para mayor concurrencia
- [ ] CI/CD con GitHub Actions
- [ ] Variables de entorno separadas: `development` / `staging` / `production`
- [ ] Monitoreo de errores con Sentry