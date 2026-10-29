# Inventario de SQL directo en C#

Proyecto: Trilogia-Cursos / DistribuidoraJJ / Licorera La Bodega  
Rama de trabajo: `feature/qa-seguridad-arquitectura`  
Bloque: 3 - Inventario de SQL directo y migracion gradual  

## Objetivo

Cumplir la observacion del profesor: no dejar sentencias SQL directamente en codigo .NET.

Este documento clasifica los usos encontrados y propone una migracion por sub-bloques. No incluye cambios de codigo ni scripts SQL ejecutables.

## Metodo de revision

Se revisaron patrones en `Proyecto_Final` y `Proyecto_FinalAPI`:

- `new SqlCommand(`
- `CommandText`
- `CommandType.Text`
- `SELECT`, `INSERT`, `UPDATE`, `DELETE`
- `CommandType.StoredProcedure`
- llamadas a `dbo.sp_*`

## Resumen ejecutivo

El proyecto ya usa procedimientos almacenados en la mayor parte de los modulos administrativos, tienda, empleados y API de autenticacion.

La deuda principal esta concentrada en:

1. `Proyecto_Final/Services/AccountDbService.cs`
2. `Proyecto_Final/Services/AdminDbService.cs`

No se detecto concatenacion directa obvia de valores libres del usuario dentro de SQL. La mayoria de consultas directas usan parametros. Aun asi, siguen incumpliendo la regla arquitectonica de no tener SQL inline en .NET.

## Clasificacion de hallazgos

### 1. SQL directo critico por regla academica

Archivo: `Proyecto_Final/Services/AccountDbService.cs`

Consultas directas:

- `ValidateUserAsync`
  - `SELECT TOP 1` sobre `Usuarios` y `Perfiles`.
- `EmailExistsAsync`
  - `SELECT COUNT(1)` sobre `Usuarios`.
- `RegisterClientAsync`
  - `INSERT INTO Usuarios`.
- `GetProfileAsync`
  - `SELECT` de perfil de usuario.
- `EmailExistsForOtherUserAsync`
  - `SELECT COUNT(1)` para correo duplicado.
- `UpdateProfileAsync`
  - `UPDATE Usuarios`.

Riesgo:

- Alto para cumplimiento de arquitectura.
- Medio para mantenimiento, porque la logica de usuarios queda repartida entre C# y base de datos.
- Bajo a medio para inyeccion SQL, porque usa parametros.

Recomendacion:

- Migrar a procedimientos `sp_Account_*`.
- Mantener comportamiento actual.
- No tocar hash de contrasenas en este bloque.

### 2. SQL directo parametrizado en administracion

Archivo: `Proyecto_Final/Services/AdminDbService.cs`

Consultas directas:

- Sincronizacion de `CategoriaId` al crear producto.
- Sincronizacion de `CategoriaId` al editar producto.
- Actualizacion de `ImagenUrl`.
- Verificacion de factura asociada a pedido.
- Consulta de comprobante cliente por `PedidoId + UsuarioId`.
- Lineas de comprobante cliente.
- Activar/desactivar producto destacado.
- Obtener productos destacados.

Riesgo:

- Alto para cumplimiento de la regla del profesor.
- Medio para mantenimiento, porque son operaciones de negocio mezcladas con SQL en C#.
- Bajo a medio para seguridad, porque usan parametros y validaciones previas.

Recomendacion:

- Migrar por grupos pequenos.
- Priorizar pedidos/facturacion y portal cliente antes que productos destacados.

### 3. SQL dinamico controlado en permisos

Archivo: `Proyecto_Final/Services/AdminDbService.cs`

Metodos:

- `TienePermisoAsync`
- `TienePermisoPorRolAsync`

Usan `CommandText` con condiciones generadas en C# para alias de modulo y prefijos de codigo.

Riesgo:

- Medio para cumplimiento.
- Medio para mantenimiento.
- Bajo para inyeccion SQL, porque los valores se agregan como parametros y las condiciones se construyen desde alias/prefijos controlados por el codigo.

Recomendacion:

- Migrar a procedimientos dedicados.
- Mantener la compatibilidad con alias actuales:
  - `Facturacion` / `Facturación`
  - `Auditoria` / `Auditoría`
  - `Creditos` / `Créditos`
  - `Venta móvil`
  - `Pedidos`
  - `Inventario`
  - `Clientes`
  - `Consultas`

### 4. Procedimientos almacenados ya correctos

Archivos con patron mayormente correcto:

- `Proyecto_FinalAPI/Services/AccountApiDbService.cs`
- `Proyecto_Final/Services/StoreDbService.cs`
- `Proyecto_Final/Services/EmployeesDbService.cs`

Observacion:

- El API de autenticacion ya llama procedimientos `sp_Auth_*`.
- La tienda usa `sp_Store_GetProductById` y `sp_Store_CreateOrder`.
- Empleados usa procedimientos `sp_Admin_*` y `sp_Employee_*`.

Recomendacion:

- No tocar estos servicios en la primera migracion.
- Usarlos como referencia de patron.

## Plan de migracion recomendado

### Sub-bloque 3A - Pedidos, facturacion y portal cliente

Objetivo:

Eliminar SQL directo relacionado con facturas, comprobantes y pedidos.

Archivos probables:

- `Proyecto_Final/Services/AdminDbService.cs`
- `database/cu091_facturacion_portal_cliente_sp.sql`

Procedimientos sugeridos:

- `dbo.sp_Admin_OrderHasInvoice`
- `dbo.sp_Client_GetInvoiceHeaderByOrder`
- `dbo.sp_Client_GetInvoiceLines`

Notas:

- `sp_Admin_GetInvoiceByOrderId` y `sp_Admin_GenerateInvoiceFromOrder` ya fueron agregados en `cu090_admin_facturar_pedido.sql`.
- Mantener validacion por `PedidoId + UsuarioId` para cliente.
- No usar `FacturaId` directo en rutas de cliente.

Pruebas:

- Pedido sin factura muestra boton generar factura en admin.
- Pedido facturado muestra ver factura.
- Cliente solo ve comprobante propio.
- Cliente no ve comprobante de otro usuario.
- Build con 0 errores.

### Sub-bloque 3B - Usuarios, login, registro y perfil

Objetivo:

Migrar `AccountDbService.cs` a procedimientos almacenados.

Archivos probables:

- `Proyecto_Final/Services/AccountDbService.cs`
- `database/cu092_account_profile_sp.sql`

Procedimientos sugeridos:

- `dbo.sp_Account_ValidateUser`
- `dbo.sp_Account_EmailExists`
- `dbo.sp_Account_RegisterClient`
- `dbo.sp_Account_GetProfile`
- `dbo.sp_Account_EmailExistsForOtherUser`
- `dbo.sp_Account_UpdateProfile`

Reglas:

- No cambiar login normal.
- No cambiar registro.
- No cambiar recuperacion de contrasena.
- No cambiar hash de contrasenas.
- Mantener mensajes seguros.

Pruebas:

- Login admin.
- Login cliente.
- Registro cliente.
- Mi Perfil carga datos.
- Mi Perfil actualiza telefono/direccion.
- Correo duplicado en perfil no permite guardar.
- Build con 0 errores.

### Sub-bloque 3C - Inventario, destacados y permisos

Objetivo:

Migrar SQL directo restante de productos y permisos.

Archivos probables:

- `Proyecto_Final/Services/AdminDbService.cs`
- `database/cu093_admin_productos_permisos_sp.sql`

Procedimientos sugeridos:

- `dbo.sp_Admin_SyncProductCategory`
- `dbo.sp_Admin_UpdateProductImage`
- `dbo.sp_Admin_ToggleFeaturedProduct`
- `dbo.sp_Store_GetFeaturedProducts`
- `dbo.sp_Admin_ProfileHasModulePermission`
- `dbo.sp_Admin_RoleHasModulePermission`

Reglas:

- No cambiar permisos existentes.
- No inventar nombres de modulos.
- Respetar `PerfilPermisos`.
- No reintroducir `PermisosPerfil`.
- Mantener `[AdminAuthorize("Empleados")]` y demas modulos actuales.

Pruebas:

- Crear producto.
- Editar producto.
- Subir/actualizar imagen.
- Activar/desactivar destacado.
- Home/Shop muestran productos destacados si aplica.
- Acceso admin por modulos sigue funcionando.
- Acceso no autorizado sigue bloqueado.
- Build con 0 errores.

## Prioridad recomendada

1. Sub-bloque 3A: facturacion y portal cliente.
2. Sub-bloque 3B: usuarios/perfil.
3. Sub-bloque 3C: productos/permisos.

Justificacion:

- 3A esta conectado al flujo de compra y facturacion recien corregido.
- 3B toca login/perfil, por lo que debe hacerse aislado y con pruebas fuertes.
- 3C mezcla inventario y permisos; conviene dejarlo para cuando 3A y 3B esten estabilizados.

## Riesgos generales

- Cambiar login/perfil puede bloquear acceso si el procedimiento no devuelve exactamente los mismos campos.
- Cambiar permisos puede dejar modulos inaccesibles si no se replican alias y prefijos actuales.
- Cambiar facturacion cliente puede romper el comprobante si se pierde validacion por `UsuarioId`.
- Crear scripts sin orden claro puede generar diferencias entre entornos.

## Criterios para aprobar migraciones

Antes de implementar cualquier sub-bloque:

1. Presentar diagnostico puntual del sub-bloque.
2. Listar archivos exactos.
3. Proponer script SQL separado.
4. Confirmar pruebas.
5. Esperar aprobacion exacta: `Aprobado, podés implementar`.

## Estado del inventario

Este inventario no corrige SQL directo. Solo deja trazabilidad y plan de migracion.

No se tocaron:

- `appsettings`
- `Proyecto_FinalAPI`
- controladores
- servicios
- modelos
- vistas
- SQL existente
- `bin/`
- `obj/`
- `.vs/`
- ZIPs
