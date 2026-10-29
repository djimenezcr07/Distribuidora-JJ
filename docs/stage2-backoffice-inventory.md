# Stage 2.3 — inventario del Backoffice Core

Fuente de verdad: controladores, modelos y vistas de `Proyecto_Final`. Este inventario registra las superficies revisadas antes de la migración visual; no cambia contratos ni permisos.

| Dominio | Controlador / acciones | Vista / modelo | Autorización y contratos preservados |
|---|---|---|---|
| Admin | `Admin.Index` | `Admin/Index`, dashboard existente | Sesión administrativa; 3 accesos principales y 11 secundarios |
| Inventario | `Inventory.Index`, `Create`, `Edit`, `Movements`, `RegisterMovement`, `TransformStock`, `RemoveImage`, `ToggleFeatured`, `ToggleStatus`, `DeletePermanent` | `ProductAdminViewModel`, `ProductFormViewModel`, `InventoryMovement*`, `StockTransformationFormViewModel` | `INVENTARIO_VER` y permisos específicos; antiforgery, IDs y POST sin cambios |
| Inteligencia | `InventoryIntelligence.Index` | `InventoryIntelligenceViewModel` | `INVENTARIO_INTELIGENCIA_VER`; filtros GET reales y alternativa tabular de gráfica |
| Combos | `Combos.Index`, `Create`, `Detail` | `ComboListItemViewModel` y vistas asociadas | Índice migrado; creación y detalle quedan como superficies vinculadas pendientes |
| Devoluciones | `Returns.Index`, `Quarantine`, `Create`, `Release`, `Discard` | `ReturnsIndexViewModel`, `ReturnListItemViewModel` | Listado, alta y cuarentena migrados; POST, antiforgery y confirmaciones preservados |
| Pedidos | `OrdersAdmin.Index`, `Detail`, `UpdateStatus` | `OrderAdminListItemViewModel`, `OrderDetailViewModel` | `AdminAuthorize("Pedidos")` y `PEDIDOS_CAMBIAR_ESTADO`; antiforgery y valores de estado intactos |
| Facturación vinculada | `Billing.Detail`, `GenerateFromOrder` | Acción contextual desde detalle de pedido | Factura solo cuando `HasInvoice` / `CanGenerateInvoice`; confirmación descriptiva |
| Proveedores | `Suppliers.Index`, `Save`, `ChangeStatus` | `SuppliersIndexViewModel` | `PROVEEDORES_VER` / `PROVEEDORES_GESTIONAR`; names e IDs usados por JavaScript preservados |
| Órdenes de compra | `PurchaseOrders.Index`, `Create`, `Suggestions`, `Detail`, `Receive`, `CloseWithDiscrepancy`, `Cancel` | `PurchaseOrder*ViewModel` | Permisos `COMPRAS_*`; `TokenOperacion`, límite de líneas, binding y antiforgery intactos |
| Histórico de precios | `PriceHistory.Index` | `PriceHistoryViewModel` | `COMPRAS_PRECIOS_VER`; consulta GET real por producto |
| Acceso denegado | `Account.AccesoDenegado` | Vista transversal | 403 sin detalles internos; acciones seguras de volver e inicio |

## Patrones aplicados

- Densidad compacta en tablas, con objetivos táctiles de 44 px.
- Filtros visibles solo cuando el backend los procesa.
- Acción frecuente visible y acciones secundarias en menú de desbordamiento donde ya existen.
- Estados expresados con texto y color semántico.
- Scroll horizontal local, nunca global.
- Formularios con etiquetas visibles, resumen de validación enfocable y contratos MVC sin cambios.
- Recepción y discrepancias explican consecuencia antes de confirmar.

## Alcance diferido

Creación/detalle de combos y vistas no centrales de sugerencias mantienen su UI previa para una migración posterior. No se inventaron datos, rutas, permisos, filtros, sorting, acciones masivas ni timelines.
