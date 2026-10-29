# Cambios administrativos incluidos

## Modulos agregados

- Dashboard administrativo
- Gestion de inventario
- Registro de movimientos de inventario
- Gestion de pedidos administrativos
- Facturacion y finanzas

## Archivos nuevos principales

- `Proyecto_Final/Filters/AdminAuthorizeAttribute.cs`
- `Proyecto_Final/Services/AdminDbService.cs`
- `Proyecto_Final/Controllers/AdminController.cs`
- `Proyecto_Final/Controllers/InventoryController.cs`
- `Proyecto_Final/Controllers/OrdersAdminController.cs`
- `Proyecto_Final/Controllers/BillingController.cs`
- `Proyecto_Final/Models/Admin/*`
- `Proyecto_Final/Views/Admin/*`
- `Proyecto_Final/Views/Inventory/*`
- `Proyecto_Final/Views/OrdersAdmin/*`
- `Proyecto_Final/Views/Billing/*`
- `Proyecto_Final/wwwroot/css/admin.css`

## Archivos modificados

- `Proyecto_Final/Program.cs`
- `Proyecto_Final/Views/Shared/_Layout.cshtml`
- `database/DistribuidoraJJ_DB.sql`
- `database/password_reset_patch.sql`

## Base de datos

La base de datos sigue siendo `DistribuidoraJJ_DB` en SQL Server.

Se agregaron estas tablas:

- `MovimientosInventario`
- `Facturas`
- `FacturaDetalle`
- `PasswordResetTokens`

## Usuario administrador de prueba

- Correo: `<demo-email>`
- Contrasena: `<demo-password>`

Las credenciales temporales se solicitan al responsable del entorno por un canal privado. No reutilizar cuentas demo ni contrasenas de scripts historicos en Azure.

## Orden recomendado para levantarlo

1. Abrir la solucion en Visual Studio 2022.
2. Ejecutar `database/DistribuidoraJJ_DB.sql` en SQL Server.
3. Confirmar la cadena de conexion en ambos `appsettings.json`.
4. Establecer inicio multiple para `Proyecto_Final` y `Proyecto_FinalAPI`.
5. Correr ambos proyectos.
6. Iniciar sesion con una cuenta temporal aprobada para el entorno.

## Nota importante

La compilacion debe validarse con la solucion y configuracion local del colaborador. No versionar cadenas de conexion ni credenciales locales.
