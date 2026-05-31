# API Reference — BENJI KDS Backend

> **Base URL:** `http://localhost:8000/api/v1`
> **Autenticación:** Bearer Token (JWT) en header `Authorization`
> **Rate limiting:** por usuario autenticado (ver límites por endpoint)

---

## Índice

1. [Auth](#1-auth)
2. [Empresas](#2-empresas)
3. [Sucursales](#3-sucursales)
4. [Usuarios × Sucursales](#4-usuarios--sucursales)
5. [Perfiles](#5-perfiles)
6. [Categorías](#6-categorías)
7. [Productos](#7-productos)
8. [Variantes de Producto](#8-variantes-de-producto)
9. [Combos](#9-combos)
10. [Recetas](#10-recetas)
11. [Clientes](#11-clientes)
12. [Proveedores](#12-proveedores)
13. [Cajas y Sesiones](#13-cajas-y-sesiones)
14. [Mesas](#14-mesas)
15. [Métodos de Pago](#15-métodos-de-pago)
16. [Pedidos](#16-pedidos)
17. [Pagos y Divisiones](#17-pagos-y-divisiones)
18. [Órdenes de Compra](#18-órdenes-de-compra)
19. [Materias Primas](#19-materias-primas)
20. [Lotes de Inventario](#20-lotes-de-inventario)
21. [Movimientos de Inventario](#21-movimientos-de-inventario)
22. [Auditoría](#22-auditoría)

---

## 1. Auth

**Prefix:** `/auth`

| Método | Ruta | Descripción | Límite | Rol mínimo |
|--------|------|-------------|--------|------------|
| `POST` | `/auth/login` | Iniciar sesión con email y contraseña | 5/min | — |
| `POST` | `/auth/register` | Registrar una empresa + admin | 3/hora | — |
| `POST` | `/auth/refresh` | Renovar access token con refresh token | 20/min | Autenticado |
| `POST` | `/auth/logout` | Cerrar sesión e invalidar token | 10/min | Autenticado |
| `GET`  | `/auth/me` | Ver mi propio perfil y empresa | — | Autenticado |
| `POST` | `/auth/invite` | Crear empleado e invitarlo a una sucursal | 20/hora | admin_empresa |
| `POST` | `/auth/change-password` | Cambiar contraseña (requiere contraseña actual) | 5/hora | Autenticado |

**Notas:**
- El registro crea un usuario en Supabase Auth + perfil con rol `admin_empresa`. Si falla algún paso, se hace rollback completo.
- `/invite` sigue un flujo de 3 pasos (Auth → Perfil → Asignación de sucursal) con rollback automático.
- El login valida que el perfil esté en estado `activo`.

---

## 2. Empresas

**Prefix:** `/empresas` | **Acceso:** `admin_empresa` ve solo la suya; `super_admin` ve todas.

| Método | Ruta | Descripción | Límite | Rol mínimo |
|--------|------|-------------|--------|------------|
| `GET`    | `/empresas/` | Listar empresas (paginado, filtros: estado, tipo_negocio, país) | — | admin_empresa |
| `GET`    | `/empresas/{id}` | Obtener empresa por ID | — | admin_empresa |
| `POST`   | `/empresas/` | Crear empresa | 20/hora | super_admin |
| `PATCH`  | `/empresas/{id}` | Actualizar datos de empresa | 30/hora | admin_empresa |
| `DELETE` | `/empresas/{id}` | Desactivar empresa (soft delete) | 10/hora | admin_empresa |
| `DELETE` | `/empresas/{id}/hard` | Eliminar permanentemente | 5/hora | super_admin |

**Notas:**
- El identificador fiscal (`identificacion`) y el email de empresa deben ser únicos.

---

## 3. Sucursales

**Prefix:** `/sucursales`

| Método | Ruta | Descripción | Límite | Rol mínimo |
|--------|------|-------------|--------|------------|
| `GET`    | `/sucursales/` | Listar sucursales (paginado) | — | admin_empresa |
| `GET`    | `/sucursales/empresa/{empresa_id}` | Listar por empresa | — | admin_empresa |
| `GET`    | `/sucursales/{id}` | Obtener sucursal | — | admin_empresa |
| `POST`   | `/sucursales/` | Crear sucursal | 30/hora | admin_empresa |
| `PATCH`  | `/sucursales/{id}` | Actualizar sucursal | 30/hora | admin_empresa |
| `DELETE` | `/sucursales/{id}` | Desactivar + desasignar empleados (soft) | 10/hora | admin_empresa |
| `DELETE` | `/sucursales/{id}/hard` | Eliminar permanentemente | 5/hora | super_admin |

**Notas:**
- El código de sucursal debe ser único por empresa.
- El soft delete desactiva automáticamente todas las asignaciones de empleados.

---

## 4. Usuarios × Sucursales

**Prefix:** `/usuarios-sucursales`

| Método | Ruta | Descripción | Límite | Rol mínimo |
|--------|------|-------------|--------|------------|
| `GET`    | `/usuarios-sucursales/sucursal/{sucursal_id}` | Listar empleados de una sucursal | — | admin_empresa |
| `GET`    | `/usuarios-sucursales/usuario/{usuario_id}` | Listar sucursales de un usuario | — | admin_empresa |
| `POST`   | `/usuarios-sucursales/` | Asignar usuario a sucursal | 30/hora | admin_empresa |
| `PATCH`  | `/usuarios-sucursales/{asignacion_id}` | Actualizar asignación | 30/hora | admin_empresa |
| `DELETE` | `/usuarios-sucursales/{asignacion_id}` | Desactivar asignación (soft) | 10/hora | admin_empresa |
| `DELETE` | `/usuarios-sucursales/{asignacion_id}/hard` | Eliminar permanentemente | 5/hora | super_admin |

**Notas:**
- No pueden existir dos asignaciones activas del mismo usuario a la misma sucursal.
- Si se elimina la asignación principal, el sistema promueve otra automáticamente.

---

## 5. Perfiles

**Prefix:** `/perfiles`

| Método | Ruta | Descripción | Límite | Rol mínimo |
|--------|------|-------------|--------|------------|
| `GET`    | `/perfiles/me` | Mi perfil completo | — | Autenticado |
| `PATCH`  | `/perfiles/me` | Actualizar mi perfil (sin cambiar rol/estado) | 20/hora | Autenticado |
| `GET`    | `/perfiles/` | Listar perfiles (paginado) | — | admin_empresa |
| `GET`    | `/perfiles/empresa/{empresa_id}` | Listar por empresa | — | admin_empresa |
| `GET`    | `/perfiles/{usuario_id}` | Obtener perfil por ID | — | admin_empresa |
| `PATCH`  | `/perfiles/{usuario_id}/rol` | Cambiar rol global | 20/hora | super_admin |
| `PATCH`  | `/perfiles/{usuario_id}/estado` | Activar / suspender / inactivar | 20/hora | admin_empresa |
| `DELETE` | `/perfiles/{usuario_id}` | Soft delete (cierra sesiones activas) | 10/hora | admin_empresa |
| `DELETE` | `/perfiles/{usuario_id}/hard` | Eliminar de Supabase Auth | 5/hora | super_admin |

**Notas:**
- Roles disponibles: `super_admin`, `admin_empresa`, `empleado`.
- Estados disponibles: `activo`, `inactivo`, `suspendido`.
- Un usuario no puede cambiar su propio rol ni estado.

---

## 6. Categorías

**Prefix:** `/categorias`

| Método | Ruta | Descripción | Límite | Rol mínimo |
|--------|------|-------------|--------|------------|
| `GET`    | `/categorias/` | Listar categorías (paginado, `super_admin` debe enviar `empresa_id`) | — | Autenticado |
| `GET`    | `/categorias/{id}` | Obtener categoría | — | Autenticado |
| `GET`    | `/categorias/{id}/subcategorias` | Listar subcategorías directas | — | Autenticado |
| `POST`   | `/categorias/` | Crear categoría (puede tener padre) | 60/hora | admin_empresa |
| `PATCH`  | `/categorias/{id}` | Actualizar | 60/hora | admin_empresa |
| `DELETE` | `/categorias/{id}` | Desactivar + subcategorías en cascada | 20/hora | admin_empresa |
| `DELETE` | `/categorias/{id}/hard` | Eliminar permanentemente | 10/hora | super_admin |

**Notas:**
- Soporta jerarquía de categorías (padre → hijo). No se permiten ciclos.
- El código debe ser único por empresa.

---

## 7. Productos

**Prefix:** `/productos`

| Método | Ruta | Descripción | Límite | Rol mínimo |
|--------|------|-------------|--------|------------|
| `GET`    | `/productos/` | Listar todos (paginado) | — | Autenticado |
| `GET`    | `/productos/sucursal/{sucursal_id}` | Listar con precios y stock por sucursal | — | Autenticado |
| `GET`    | `/productos/{id}` | Obtener producto | — | Autenticado |
| `POST`   | `/productos/` | Crear producto | 60/hora | admin_empresa |
| `PATCH`  | `/productos/{id}` | Actualizar | 60/hora | admin_empresa |
| `DELETE` | `/productos/{id}` | Soft delete (desactiva en todas las sucursales) | 20/hora | admin_empresa |
| `DELETE` | `/productos/{id}/hard` | Eliminar permanentemente | 10/hora | super_admin |
| `GET`    | `/productos/{id}/sucursales/{sucursal_id}` | Precio y stock en sucursal específica | — | admin_empresa |
| `POST`   | `/productos/{id}/sucursales` | Configurar precio/stock en sucursal | 60/hora | admin_empresa |
| `PATCH`  | `/productos/sucursales/{ps_id}` | Actualizar precio o stock | 60/hora | admin_empresa |
| `DELETE` | `/productos/sucursales/{ps_id}` | Eliminar configuración de sucursal | 20/hora | admin_empresa |

**Notas:**
- Tipos de producto: `simple`, `compuesto`, `combo`.
- El código interno debe ser único por empresa.
- Requiere categoría de la misma empresa.

---

## 8. Variantes de Producto

**Prefix:** `/productos/{producto_id}/variantes`

| Método | Ruta | Descripción | Límite | Rol mínimo |
|--------|------|-------------|--------|------------|
| `GET`    | `/variantes` | Listar todas las variantes del producto | — | Autenticado |
| `GET`    | `/variantes/{variante_id}` | Obtener variante | — | Autenticado |
| `POST`   | `/variantes` | Agregar variante (ej: talla S, color rojo) | 30/hora | admin_empresa |
| `PATCH`  | `/variantes/{variante_id}` | Actualizar variante | 30/hora | admin_empresa |
| `DELETE` | `/variantes/{variante_id}` | Eliminar variante | 20/hora | admin_empresa |

**Notas:**
- Solo para productos de tipo `simple` o `compuesto`.
- El nombre de la variante debe ser único por producto.

---

## 9. Combos

**Prefix:** `/productos/{producto_id}/combos`

| Método | Ruta | Descripción | Límite | Rol mínimo |
|--------|------|-------------|--------|------------|
| `GET`    | `/combos` | Listar componentes del combo | — | Autenticado |
| `GET`    | `/combos/{componente_id}` | Obtener componente | — | Autenticado |
| `POST`   | `/combos` | Agregar producto al combo | 30/hora | admin_empresa |
| `PATCH`  | `/combos/{componente_id}` | Actualizar cantidad o si es opcional | 30/hora | admin_empresa |
| `DELETE` | `/combos/{componente_id}` | Eliminar del combo | 20/hora | admin_empresa |

**Notas:**
- Solo para productos de tipo `combo`.
- Un combo no puede contenerse a sí mismo ni a otro combo.
- Cada componente tiene `cantidad` y flag `is_opcional`.

---

## 10. Recetas

**Prefix:** `/productos/{producto_id}/receta`

| Método | Ruta | Descripción | Límite | Rol mínimo |
|--------|------|-------------|--------|------------|
| `GET`    | `/receta` | Obtener ingredientes de la receta | — | Autenticado |
| `GET`    | `/receta/{receta_id}` | Obtener ingrediente | — | Autenticado |
| `POST`   | `/receta` | Agregar ingrediente (materia prima) | 60/hora | admin_empresa |
| `PATCH`  | `/receta/{receta_id}` | Actualizar cantidad o unidad | 60/hora | admin_empresa |
| `DELETE` | `/receta/{receta_id}` | Eliminar ingrediente | 30/hora | admin_empresa |

**Notas:**
- La materia prima debe pertenecer a la misma empresa.
- No se puede repetir la misma materia prima en la misma receta.

---

## 11. Clientes

**Prefix:** `/clientes`

| Método | Ruta | Descripción | Límite | Rol mínimo |
|--------|------|-------------|--------|------------|
| `GET`    | `/clientes/` | Listar clientes (paginado) | — | Autenticado |
| `GET`    | `/clientes/{id}` | Obtener cliente | — | Autenticado |
| `POST`   | `/clientes/` | Crear cliente | 60/hora | Autenticado |
| `PATCH`  | `/clientes/{id}` | Actualizar datos | 30/hora | Autenticado |
| `PATCH`  | `/clientes/{id}/puntos` | Ajustar puntos de fidelidad | 30/hora | admin_empresa |
| `DELETE` | `/clientes/{id}` | Soft delete | 10/hora | admin_empresa |
| `DELETE` | `/clientes/{id}/hard` | Eliminar permanentemente (falla si tiene pedidos) | 5/hora | super_admin |

**Notas:**
- El identificador y el email son únicos por empresa.
- Los puntos de fidelidad no pueden ser negativos.
- Al facturar un pedido, se actualizan automáticamente `total_gasto` y `total_pedidos` del cliente.

---

## 12. Proveedores

**Prefix:** `/proveedores`

| Método | Ruta | Descripción | Límite | Rol mínimo |
|--------|------|-------------|--------|------------|
| `GET`    | `/proveedores/` | Listar (paginado) | — | admin_empresa |
| `GET`    | `/proveedores/{id}` | Obtener proveedor | — | admin_empresa |
| `POST`   | `/proveedores/` | Crear proveedor | 30/hora | admin_empresa |
| `PATCH`  | `/proveedores/{id}` | Actualizar | 30/hora | admin_empresa |
| `DELETE` | `/proveedores/{id}` | Soft delete | 10/hora | admin_empresa |
| `DELETE` | `/proveedores/{id}/hard` | Eliminar permanentemente (falla si tiene órdenes) | 5/hora | super_admin |

**Notas:**
- Estado `bloqueado` impide crear nuevas órdenes de compra a ese proveedor.
- El identificador fiscal y el código deben ser únicos por empresa.

---

## 13. Cajas y Sesiones

**Prefix:** `/cajas`

### Cajas

| Método | Ruta | Descripción | Límite | Rol mínimo |
|--------|------|-------------|--------|------------|
| `GET`    | `/cajas/` | Listar cajas por sucursal | — | admin_empresa |
| `GET`    | `/cajas/{id}` | Obtener caja | — | admin_empresa |
| `POST`   | `/cajas/` | Crear caja | 30/hora | admin_empresa |
| `PATCH`  | `/cajas/{id}` | Actualizar | 30/hora | admin_empresa |
| `DELETE` | `/cajas/{id}` | Soft delete (falla si hay sesión abierta) | 10/hora | admin_empresa |
| `DELETE` | `/cajas/{id}/hard` | Eliminar permanentemente | 5/hora | super_admin |

### Sesiones de Caja

| Método | Ruta | Descripción | Límite | Rol mínimo |
|--------|------|-------------|--------|------------|
| `GET`    | `/cajas/{id}/sesiones` | Listar sesiones (paginado) | — | admin_empresa |
| `GET`    | `/cajas/{id}/sesiones/activa` | Obtener sesión activa | — | Autenticado |
| `GET`    | `/cajas/sesiones/{sesion_id}` | Obtener sesión por ID | — | admin_empresa |
| `POST`   | `/cajas/{id}/sesiones/abrir` | Abrir sesión de caja | 10/hora | Autenticado |
| `PATCH`  | `/cajas/sesiones/{id}/cerrar` | Cerrar sesión (solo el que la abrió o admin) | 10/hora | Autenticado |
| `PATCH`  | `/cajas/sesiones/{id}/auditar` | Auditar sesión cerrada | 10/hora | admin_empresa |

### Movimientos de Caja

| Método | Ruta | Descripción | Límite | Rol mínimo |
|--------|------|-------------|--------|------------|
| `GET`    | `/cajas/sesiones/{id}/movimientos` | Listar movimientos | — | Autenticado |
| `POST`   | `/cajas/sesiones/{id}/movimientos` | Registrar movimiento (entradas/salidas manuales) | 120/hora | Autenticado |
| `DELETE` | `/cajas/sesiones/{id}/movimientos/{m_id}` | Eliminar movimiento | 5/hora | super_admin |

**Notas:**
- Solo puede haber una sesión activa por caja.
- Estados de sesión: `abierta` → `cerrada` → `auditada`.
- La diferencia de caja = `monto_cierre - monto_apertura - total_movimientos`.

---

## 14. Mesas

**Prefix:** `/mesas`

| Método | Ruta | Descripción | Límite | Rol mínimo |
|--------|------|-------------|--------|------------|
| `GET`    | `/mesas/` | Listar mesas de una sucursal (filtros: estado, zona) | — | Autenticado |
| `GET`    | `/mesas/{id}` | Obtener mesa | — | Autenticado |
| `GET`    | `/mesas/{id}/pedido-activo` | Pedido en curso no terminal de la mesa | — | Autenticado |
| `POST`   | `/mesas/` | Crear mesa | 60/hora | admin_empresa |
| `PATCH`  | `/mesas/{id}` | Actualizar datos (nombre, capacidad, zona, notas) | 60/hora | admin_empresa |
| `PATCH`  | `/mesas/{id}/estado` | Cambiar estado de la mesa | 120/hora | Autenticado |
| `DELETE` | `/mesas/{id}` | Desactivar mesa (soft delete) | 20/hora | admin_empresa |
| `DELETE` | `/mesas/{id}/hard` | Eliminar permanentemente | 5/hora | super_admin |

**Estados de mesa:**

| Estado | Significado |
|--------|-------------|
| `libre` | Disponible para ser asignada |
| `ocupada` | Con clientes activos |
| `reservada` | Reservada (sin clientes aún) |
| `fuera_de_servicio` | Inhabilitada temporalmente |

**Notas:**
- El número de mesa debe ser único por sucursal.
- Al crear, el estado inicia automáticamente en `libre`.
- No se puede desactivar (soft delete) una mesa con estado `ocupada`.
- El hard delete falla si la mesa tiene un pedido activo (no facturado/cancelado).
- `GET /pedido-activo` devuelve 404 si no hay pedido activo en la mesa.
- La tabla `pedidos.mesa_id` tiene FK hacia `mesas.id` (ejecutar `ALTER TABLE` en `SQL/mesas.sql`).

---

## 15. Métodos de Pago

**Prefix:** `/metodos-pago`

| Método | Ruta | Descripción | Límite | Rol mínimo |
|--------|------|-------------|--------|------------|
| `GET`    | `/metodos-pago/` | Listar métodos de pago de la empresa (filtro: tipo, solo_activos) | — | Autenticado |
| `GET`    | `/metodos-pago/{id}` | Obtener método de pago | — | Autenticado |
| `POST`   | `/metodos-pago/` | Crear método de pago | 30/hora | admin_empresa |
| `PATCH`  | `/metodos-pago/{id}` | Actualizar (excepto el campo `codigo`) | 30/hora | admin_empresa |
| `DELETE` | `/metodos-pago/{id}` | Desactivar método de pago (soft delete) | 20/hora | admin_empresa |
| `DELETE` | `/metodos-pago/{id}/hard` | Eliminar permanentemente | 5/hora | super_admin |

**Tipos disponibles (`tipo`):**

| Tipo | Descripción |
|------|-------------|
| `efectivo` | Dinero en efectivo |
| `tarjeta_debito` | Tarjeta de débito |
| `tarjeta_credito` | Tarjeta de crédito |
| `transferencia` | Transferencia bancaria |
| `sinpe` | SINPE Móvil |
| `cheque` | Cheque bancario |
| `credito` | Crédito interno (cuenta del cliente) |
| `qr` | Pago por código QR |
| `crypto` | Criptomoneda |
| `otros` | Otros métodos |

**Notas:**
- El campo `codigo` es el identificador único por empresa (ej: `"efectivo"`, `"visa_credito"`). No se puede cambiar después de crear.
- `comision_porcentaje` va de `0` a `0.9999` (ej: `0.0350` = 3.5%).
- `permite_vuelto: true` solo tiene sentido para métodos de tipo `efectivo`.
- Los métodos desactivados siguen siendo visibles con `solo_activos=false` (para historial de pagos).

---

## 16. Pedidos

**Prefix:** `/pedidos`

| Método | Ruta | Descripción | Límite | Rol mínimo |
|--------|------|-------------|--------|------------|
| `GET`    | `/pedidos/` | Listar pedidos (paginado, filtros: estado, mesa, fecha, cliente, tipo…) | — | Autenticado |
| `GET`    | `/pedidos/{id}` | Obtener pedido | — | Autenticado |
| `GET`    | `/pedidos/{id}/detalle` | Obtener pedido con todos sus ítems | — | Autenticado |
| `POST`   | `/pedidos/` | Crear pedido | 120/hora | Autenticado |
| `PATCH`  | `/pedidos/{id}` | Actualizar datos (solo en `borrador` o `abierto`) | 60/hora | Autenticado |
| `PATCH`  | `/pedidos/{id}/estado` | Avanzar estado del pedido | 60/hora | Autenticado |
| `DELETE` | `/pedidos/{id}/hard` | Eliminar permanentemente (solo `borrador` / `cancelado`) | 5/hora | super_admin |
| `POST`   | `/pedidos/{id}/items` | Agregar ítem al pedido | 120/hora | Autenticado |
| `PATCH`  | `/pedidos/{id}/items/{item_id}` | Actualizar ítem | 120/hora | Autenticado |
| `DELETE` | `/pedidos/{id}/items/{item_id}` | Cancelar ítem (con motivo) | 60/hora | Autenticado |

**Tipos de pedido (`tipo_pedido`):**

| Valor | Caso de uso |
|-------|-------------|
| `mesa` | Cliente sentado en mesa de restaurante |
| `mostrador` | Compra directa en caja (tienda / POS) |
| `para_llevar` | Pedido para llevar, sin mesa |
| `domicilio` | Delivery (requiere `direccion_entrega`) |

**Flujo de estados:**
```
borrador → abierto → en_preparacion → listo → en_entrega → entregado → facturado
                                          ↘ cualquier estado → cancelado
```

**Notas:**
- Al facturar (`estado: facturado`) es **obligatorio** enviar `sesion_caja_id`.
- Al facturar, se actualizan automáticamente los stats del cliente (si tiene).
- Los totales se recalculan automáticamente al agregar/cancelar ítems.

---

## 17. Pagos y Divisiones

**Prefix:** `/pedidos/{pedido_id}/pagos` y `/pedidos/{pedido_id}/divisiones`

### Pagos

| Método | Ruta | Descripción | Límite | Rol mínimo |
|--------|------|-------------|--------|------------|
| `GET`    | `/pedidos/{id}/pagos` | Listar pagos del pedido | — | Autenticado |
| `GET`    | `/pedidos/{id}/pagos/resumen` | Resumen: total pagado, desglose por método | — | Autenticado |
| `POST`   | `/pedidos/{id}/pagos` | Registrar pago | 30/hora | Autenticado |
| `PATCH`  | `/pedidos/{id}/pagos/{pago_id}/estado` | Reversar o rechazar un pago | 10/hora | admin_empresa |
| `GET`    | `/cajas/sesiones/{sesion_id}/pagos` | Listar pagos de una sesión de caja | — | admin_empresa |

### Divisiones (dividir cuenta)

| Método | Ruta | Descripción | Límite | Rol mínimo |
|--------|------|-------------|--------|------------|
| `GET`    | `/pedidos/{id}/divisiones` | Listar divisiones | — | Autenticado |
| `GET`    | `/pedidos/{id}/divisiones/{div_id}` | Obtener división con ítems | — | Autenticado |
| `POST`   | `/pedidos/{id}/divisiones` | Crear división (por ítems o por cantidad) | 20/hora | Autenticado |
| `PATCH`  | `/pedidos/{id}/divisiones/{div_id}/pagar` | Marcar división como pagada | 20/hora | Autenticado |
| `DELETE` | `/pedidos/{id}/divisiones/{div_id}` | Eliminar división (solo pendiente) | 10/hora | Autenticado |

**Notas:**
- Registrar un pago requiere sesión de caja activa (`sesion_caja_id`).
- No se puede pagar un pedido `cancelado` o `facturado`.
- Estados de pago: `completado`, `reversado`, `rechazado`.
- Las divisiones permiten dividir la cuenta por ítems (`split_by_items`) o por cantidad de personas (`split_count`).

---

## 18. Órdenes de Compra

**Prefix:** `/ordenes-compra`

| Método | Ruta | Descripción | Límite | Rol mínimo |
|--------|------|-------------|--------|------------|
| `GET`    | `/ordenes-compra/` | Listar (paginado) | — | admin_empresa |
| `GET`    | `/ordenes-compra/{id}` | Obtener orden | — | admin_empresa |
| `GET`    | `/ordenes-compra/{id}/detalle` | Obtener con ítems | — | admin_empresa |
| `POST`   | `/ordenes-compra/` | Crear orden de compra | 30/hora | admin_empresa |
| `PATCH`  | `/ordenes-compra/{id}` | Actualizar (solo en `borrador`) | 30/hora | admin_empresa |
| `PATCH`  | `/ordenes-compra/{id}/estado` | Avanzar estado | 20/hora | admin_empresa |
| `DELETE` | `/ordenes-compra/{id}` | Cancelar orden | 10/hora | admin_empresa |
| `DELETE` | `/ordenes-compra/{id}/hard` | Eliminar permanentemente (solo `borrador`/`cancelada`) | 5/hora | super_admin |
| `POST`   | `/ordenes-compra/{id}/items` | Agregar ítem (solo `borrador`) | 60/hora | admin_empresa |
| `PATCH`  | `/ordenes-compra/{id}/items/{item_id}` | Actualizar ítem (solo `borrador`) | 60/hora | admin_empresa |
| `DELETE` | `/ordenes-compra/{id}/items/{item_id}` | Eliminar ítem (solo `borrador`) | 30/hora | admin_empresa |
| `PATCH`  | `/ordenes-compra/{id}/items/{item_id}/recepcion` | Registrar recepción parcial o total | 60/hora | admin_empresa |

**Flujo de estados:**
```
borrador → enviada → confirmada → parcial → recibida
              ↘ cualquier estado (excepto recibida / cancelada) → cancelada
```

**Notas:**
- El proveedor no debe estar en estado `bloqueado`.
- Al registrar recepción, `cantidad_recibida` no puede superar `cantidad_solicitada`.
- Requiere `fecha_entrega_real` al marcar como `recibida`.

---

## 19. Materias Primas

**Prefix:** `/materias-primas`

| Método | Ruta | Descripción | Límite | Rol mínimo |
|--------|------|-------------|--------|------------|
| `GET`    | `/materias-primas/` | Listar (paginado) | — | admin_empresa |
| `GET`    | `/materias-primas/sucursal/{sucursal_id}` | Listar con stock; filtro `bajo_minimo` | — | Autenticado |
| `GET`    | `/materias-primas/{id}` | Obtener | — | Autenticado |
| `POST`   | `/materias-primas/` | Crear materia prima | 60/hora | admin_empresa |
| `PATCH`  | `/materias-primas/{id}` | Actualizar | 60/hora | admin_empresa |
| `DELETE` | `/materias-primas/{id}` | Soft delete | 10/hora | admin_empresa |
| `DELETE` | `/materias-primas/{id}/hard` | Eliminar (falla si tiene recetas o lotes) | 5/hora | super_admin |
| `GET`    | `/materias-primas/{id}/sucursales/{sucursal_id}` | Stock en sucursal específica | — | Autenticado |
| `POST`   | `/materias-primas/{id}/sucursales` | Configurar stock/costos en sucursal | 60/hora | admin_empresa |
| `PATCH`  | `/materias-primas/sucursales/{mps_id}` | Actualizar stock o costo | 60/hora | admin_empresa |
| `DELETE` | `/materias-primas/sucursales/{mps_id}` | Eliminar configuración | 10/hora | admin_empresa |

**Notas:**
- Las materias perecederas requieren `dias_vida_util`.
- El código debe ser único por empresa.

---

## 20. Lotes de Inventario

**Prefix:** `/lotes`

| Método | Ruta | Descripción | Límite | Rol mínimo |
|--------|------|-------------|--------|------------|
| `GET`    | `/lotes/` | Listar (filtros: materia_prima, producto, estado, próximos a vencer) | — | Autenticado |
| `GET`    | `/lotes/{id}` | Obtener lote | — | Autenticado |
| `POST`   | `/lotes/` | Registrar nuevo lote | 60/hora | Autenticado |
| `PATCH`  | `/lotes/{id}` | Actualizar (falla si está `agotado`) | 30/hora | admin_empresa |
| `PATCH`  | `/lotes/vencidos/marcar` | Marcar como vencidos todos los expirados de una sucursal | 10/hora | admin_empresa |
| `DELETE` | `/lotes/{id}/hard` | Eliminar (solo `agotado` o `vencido`) | 5/hora | super_admin |

**Notas:**
- Un lote referencia **solo** una materia prima **o** un producto, no ambos.
- `cantidad_actual` no puede superar `cantidad_inicial`.
- Estados: `activo`, `vencido`, `agotado`.

---

## 21. Movimientos de Inventario

**Prefix:** `/movimientos-inventario`

| Método | Ruta | Descripción | Límite | Rol mínimo |
|--------|------|-------------|--------|------------|
| `GET`    | `/movimientos-inventario/` | Listar (paginado, por empresa) | — | admin_empresa |
| `GET`    | `/movimientos-inventario/{id}` | Obtener movimiento | — | Autenticado |
| `GET`    | `/movimientos-inventario/{id}/detalle` | Obtener con ítems | — | Autenticado |
| `POST`   | `/movimientos-inventario/` | Crear movimiento | 30/hora | Autenticado |
| `PATCH`  | `/movimientos-inventario/{id}` | Actualizar (solo `borrador`) | 30/hora | Autenticado |
| `PATCH`  | `/movimientos-inventario/{id}/estado` | Completar o cancelar | 20/hora | Autenticado |
| `DELETE` | `/movimientos-inventario/{id}/hard` | Eliminar (`borrador` / `cancelado`) | 5/hora | super_admin |
| `POST`   | `/movimientos-inventario/{id}/items` | Agregar ítem (solo `borrador`) | 60/hora | Autenticado |
| `DELETE` | `/movimientos-inventario/{id}/items/{item_id}` | Eliminar ítem (solo `borrador`) | 30/hora | Autenticado |

**Tipos de movimiento:**

| Tipo | Descripción |
|------|-------------|
| `entrada` | Ingreso de stock (ej: recepción de compra) |
| `salida` | Consumo o merma de stock |
| `transferencia` | De una sucursal a otra |
| `ajuste` | Corrección de inventario |
| `devolucion` | Devolución a proveedor o de cliente |

**Notas:**
- `transferencia` requiere `sucursal_origen` y `sucursal_destino`.
- Al completar, actualiza el stock en `productos_sucursales`.
- Cancelar un movimiento ya completado **no revierte** el stock; se necesita un movimiento inverso.

---

## 22. Auditoría

**Prefix:** `/auditoria` y `/pedidos/{id}/historial`

| Método | Ruta | Descripción | Límite | Rol mínimo |
|--------|------|-------------|--------|------------|
| `GET` | `/pedidos/{id}/historial` | Historial de cambios de estado del pedido | — | Autenticado |
| `GET` | `/pedidos/{id}/items/{item_id}/historial` | Historial de cambios de un ítem | — | Autenticado |
| `GET` | `/auditoria/` | Log completo de auditoría (filtrable por tabla, acción, fecha) | — | super_admin |
| `GET` | `/auditoria/registro/{tabla}/{registro_id}` | Historial de cualquier registro | — | super_admin |

**Tablas auditadas:** `pedidos`, `detalle_pedidos`, `productos`, `categorias`, `clientes`, `proveedores`, `empleados`, `cajas`, `sesiones_caja`, `ordenes_compra`, `movimientos_inventario`.

---
---

# Flujos de la Aplicación

> Los flujos están organizados por escenario de negocio. Cada paso referencia los endpoints correspondientes.

---

## Flujo 0 — Onboarding (primera vez)

> Para cuando un negocio se registra por primera vez.

```
1. Crear empresa
   POST /empresas/
   └─ Solo super_admin puede crear empresas

2. Registrar admin del negocio
   POST /auth/register
   └─ Crea usuario + perfil admin_empresa en un solo paso

3. Crear sucursal(es)
   POST /sucursales/

4. Invitar empleados
   POST /auth/invite
   └─ Crea usuario, perfil y asignación a sucursal en un solo paso

5. Crear categorías
   POST /categorias/

6. Crear productos y configurarlos por sucursal
   POST /productos/
   POST /productos/{id}/sucursales  ← precio y stock por sucursal

7. Crear caja(s) registradoras
   POST /cajas/
```

---

## Flujo 1 — Apertura de turno (cajero)

> Cada vez que empieza el turno de un empleado en caja.

```
1. Login
   POST /auth/login

2. Verificar caja disponible
   GET /cajas/  (filtrar por sucursal)

3. Abrir sesión de caja
   POST /cajas/{caja_id}/sesiones/abrir
   └─ Se registra monto_apertura (dinero con que inicia la caja)

4. Verificar que la sesión está activa
   GET /cajas/{caja_id}/sesiones/activa
```

---

## Flujo 2 — Venta en mostrador / caja registradora (tienda / supermercado)

> Cliente llega a la caja y compra productos directamente.

```
1. [Opcional] Buscar o crear cliente
   GET /clientes/?identificacion=...
   POST /clientes/

2. Crear pedido tipo "mostrador"
   POST /pedidos/
   {
     "tipo_pedido": "mostrador",
     "sesion_caja_id": "<id-sesion-activa>",   // opcional al crear
     "cliente_id": "<id-cliente>"              // opcional
   }

3. Agregar productos al pedido
   POST /pedidos/{id}/items
   └─ Repetir por cada producto escaneado

4. [Opcional] Modificar cantidades
   PATCH /pedidos/{id}/items/{item_id}

5. [Opcional] Cancelar un ítem equivocado
   DELETE /pedidos/{id}/items/{item_id}

6. Registrar pago
   POST /pedidos/{id}/pagos
   {
     "sesion_caja_id": "<id>",
     "metodo_pago": "efectivo" | "tarjeta" | "transferencia",
     "monto": 50.00
   }

7. Facturar el pedido
   PATCH /pedidos/{id}/estado
   {
     "estado": "facturado",
     "sesion_caja_id": "<id>"
   }
```

---

## Flujo 3 — Pedido en mesa (restaurante)

> Mesero toma el pedido de una mesa y lo envía a cocina.

```
1. Crear pedido tipo "mesa"
   POST /pedidos/
   {
     "tipo_pedido": "mesa",
     "mesa_id": "<id-mesa>",
     "numero_pedido": "M-045"
   }

2. Agregar ítems (lo que pide cada comensal)
   POST /pedidos/{id}/items

3. Confirmar y enviar a cocina
   PATCH /pedidos/{id}/estado  →  { "estado": "abierto" }

4. Cocina recibe y empieza a preparar
   PATCH /pedidos/{id}/estado  →  { "estado": "en_preparacion" }

5. Cocina termina
   PATCH /pedidos/{id}/estado  →  { "estado": "listo" }

6. Mesero entrega
   PATCH /pedidos/{id}/estado  →  { "estado": "entregado" }

7. [Opcional] Dividir la cuenta
   POST /pedidos/{id}/divisiones
   PATCH /pedidos/{id}/divisiones/{div_id}/pagar

8. Cobrar y facturar
   POST /pedidos/{id}/pagos
   PATCH /pedidos/{id}/estado  →  { "estado": "facturado", "sesion_caja_id": "<id>" }
```

---

## Flujo 4 — Pedido para llevar / para recoger

> Cliente pide por teléfono o en mostrador pero se lo lleva.

```
1. Crear pedido tipo "para_llevar"
   POST /pedidos/
   { "tipo_pedido": "para_llevar", "numero_pedido": "PL-012" }

2. Agregar ítems
   POST /pedidos/{id}/items

3. Enviar a cocina
   PATCH /pedidos/{id}/estado  →  { "estado": "abierto" }
   PATCH /pedidos/{id}/estado  →  { "estado": "en_preparacion" }
   PATCH /pedidos/{id}/estado  →  { "estado": "listo" }

4. Cliente recoge y paga
   POST /pedidos/{id}/pagos
   PATCH /pedidos/{id}/estado  →  { "estado": "facturado", "sesion_caja_id": "<id>" }
```

---

## Flujo 5 — Delivery / domicilio

> Pedido que se entrega a una dirección.

```
1. Crear pedido tipo "domicilio"
   POST /pedidos/
   {
     "tipo_pedido": "domicilio",
     "direccion_entrega": "Calle 123, Apto 4B",
     "cliente_id": "<id>"
   }

2. Agregar ítems
   POST /pedidos/{id}/items

3. Preparar y asignar repartidor
   PATCH /pedidos/{id}/estado  →  { "estado": "abierto" }
   PATCH /pedidos/{id}/estado  →  { "estado": "en_preparacion" }
   PATCH /pedidos/{id}/estado  →  { "estado": "listo" }
   PATCH /pedidos/{id}/estado  →  { "estado": "en_entrega" }

4. Confirmar entrega y facturar
   PATCH /pedidos/{id}/estado  →  { "estado": "entregado" }
   POST /pedidos/{id}/pagos
   PATCH /pedidos/{id}/estado  →  { "estado": "facturado", "sesion_caja_id": "<id>" }
```

---

## Flujo 6 — Cancelación de pedido

```
1. Cancelar ítems específicos (si aplica)
   DELETE /pedidos/{id}/items/{item_id}
   └─ Requiere motivo de cancelación

2. Cancelar el pedido completo
   PATCH /pedidos/{id}/estado
   {
     "estado": "cancelado",
     "motivo_cancelacion": "Cliente no se presentó"
   }

3. [Opcional] Eliminar el pedido (solo super_admin, solo si está cancelado)
   DELETE /pedidos/{id}/hard
```

---

## Flujo 7 — Cierre de turno (cajero)

```
1. Ver resumen de pagos de la sesión
   GET /cajas/sesiones/{sesion_id}/pagos

2. Cerrar sesión de caja
   PATCH /cajas/sesiones/{id}/cerrar
   └─ Se registra monto_cierre (dinero físico al contar)

3. [Admin] Auditar y cuadrar caja
   PATCH /cajas/sesiones/{id}/auditar
   └─ Diferencia = monto_cierre - monto_apertura - total_movimientos

4. Logout
   POST /auth/logout
```

---

## Flujo 8 — Compra de insumos a proveedor

> El negocio necesita reponer materias primas.

```
1. Verificar stock bajo
   GET /materias-primas/sucursal/{sucursal_id}?bajo_minimo=true

2. Crear orden de compra
   POST /ordenes-compra/
   { "proveedor_id": "<id>", "sucursal_id": "<id>" }

3. Agregar ítems (materias primas a pedir)
   POST /ordenes-compra/{id}/items

4. Enviar al proveedor
   PATCH /ordenes-compra/{id}/estado  →  { "estado": "enviada" }

5. Proveedor confirma
   PATCH /ordenes-compra/{id}/estado  →  { "estado": "confirmada" }

6. Registrar lo que llegó (puede ser parcial)
   PATCH /ordenes-compra/{id}/items/{item_id}/recepcion
   { "cantidad_recibida": 8 }          ← de 10 pedidas

7a. Si llegó todo:
    PATCH /ordenes-compra/{id}/estado  →  { "estado": "recibida", "fecha_entrega_real": "..." }

7b. Si llegó parcial:
    PATCH /ordenes-compra/{id}/estado  →  { "estado": "parcial" }
    └─ Registrar el resto cuando llegue → luego marcar "recibida"
```

---

## Flujo 9 — Gestión de inventario

### Entrada de stock manual
```
POST /movimientos-inventario/        { "tipo": "entrada" }
POST /movimientos-inventario/{id}/items
PATCH /movimientos-inventario/{id}/estado  →  { "estado": "completado" }
```

### Transferencia entre sucursales
```
POST /movimientos-inventario/
{ "tipo": "transferencia", "sucursal_origen": "<id>", "sucursal_destino": "<id>" }
POST /movimientos-inventario/{id}/items
PATCH /movimientos-inventario/{id}/estado  →  completado
```

### Ajuste por inventario físico
```
POST /movimientos-inventario/        { "tipo": "ajuste" }
POST /movimientos-inventario/{id}/items
PATCH /movimientos-inventario/{id}/estado  →  completado
```

### Marcar lotes vencidos
```
PATCH /lotes/vencidos/marcar         { "sucursal_id": "<id>" }
```

---

## Flujo 10 — Fidelización de clientes

```
1. Crear o buscar cliente
   POST /clientes/
   GET /clientes/?identificacion=...

2. Asociar cliente al pedido
   POST /pedidos/  { "cliente_id": "<id>", ... }

3. Al facturar, los stats se actualizan automáticamente
   PATCH /pedidos/{id}/estado  →  facturado
   └─ Incrementa total_gasto y total_pedidos del cliente

4. [Admin] Ajustar puntos manualmente
   PATCH /clientes/{id}/puntos  { "puntos": 50, "motivo": "Promoción especial" }
```

---
---

# Análisis de Gaps — Lo que hace falta

> Endpoints o funcionalidades que son necesarios para una app de restaurante/tienda completa y que **no existen aún**.

## 🔴 Crítico (bloquean flujos esenciales)

### ~~1. Mesas (`/mesas`)~~ ✅ Implementado
Ver [sección 14](#14-mesas). Router completo con CRUD, estado y pedido activo.

### ~~2. Métodos de pago configurables (`/metodos-pago`)~~ ✅ Implementado
Ver [sección 15](#15-métodos-de-pago). Router completo con CRUD y soft delete.

### 3. Webhook / Notificaciones en tiempo real para KDS
Al ser un **Kitchen Display System**, la cocina necesita recibir pedidos en tiempo real. No hay WebSockets ni integración push.
- `WS /ws/cocina/{sucursal_id}` — stream de pedidos entrantes para la pantalla de cocina
- `WS /ws/pedidos/{pedido_id}` — seguimiento en tiempo real del estado de un pedido

---

## 🟠 Importante (degradan la experiencia)

### 4. Turnos / Comandas de cocina (`/estado-cocina`)
El flujo de cocina usa `estado_cocina` en el pedido, pero no hay endpoints para que los cocineros actualicen ese campo de forma aislada sin afectar el estado general del pedido.
- `PATCH /pedidos/{id}/estado-cocina` — solo actualiza `estado_cocina` (pendiente, preparando, listo)

### 5. Reportes y dashboard
No existe ningún endpoint de reportes. Para una tienda/restaurante son esenciales:
- `GET /reportes/ventas` — ventas por día/semana/mes/sucursal
- `GET /reportes/productos-top` — productos más vendidos
- `GET /reportes/inventario` — resumen de stock actual
- `GET /reportes/caja` — cierre de caja consolidado

### 6. Reservas (`/reservas`)
Para restaurantes, las reservas de mesa son necesarias.
- `GET /reservas/` — listar reservas
- `POST /reservas/` — crear reserva (nombre, fecha, hora, personas, mesa)
- `PATCH /reservas/{id}/estado` — confirmar / cancelar / sentar

### 7. Impresión / tickets
No hay endpoint para generar el comprobante de un pedido (ticket de caja o factura).
- `GET /pedidos/{id}/ticket` — genera el ticket en texto o PDF
- `GET /pedidos/{id}/factura` — genera factura electrónica

---

## 🟡 Mejoras recomendadas

### 8. Cancelación con reembolso
Al cancelar un pago (`PATCH /pagos/{id}/estado → reversado`), no hay flujo de reembolso registrado. Falta un campo `monto_reembolso` y un movimiento de caja inverso automático.

### 9. Productos agotados en tiempo real
No hay un endpoint rápido para marcar un producto como **sin stock** desde la cocina.
- `PATCH /productos/sucursales/{ps_id}/sin-stock` — toggle rápido de disponibilidad

### 10. Historial de precios
Los precios de `productos_sucursales` se sobreescriben. No hay historial de cambios de precio, lo que complica los reportes de rentabilidad.

### 11. Descuentos y promociones (`/descuentos`)
No hay módulo de descuentos ni cupones. Las ventas solo usan precio base.
- `POST /descuentos/` — crear descuento (porcentaje, monto fijo, por código)
- `POST /pedidos/{id}/descuento` — aplicar descuento a un pedido

### 12. Propinas (`propina` en pagos)
El modelo de pagos no incluye campo de propina (`tip`). Relevante para restaurantes con servicio a la mesa.

---
