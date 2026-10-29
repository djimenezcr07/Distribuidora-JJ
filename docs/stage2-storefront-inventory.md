# Stage 2.2 — Inventario del flujo cliente

Inventario previo a la migración visual. Los controladores, ViewModels, rutas y procesamiento permanecen como fuente funcional; Stage 2.2 cambia únicamente vistas, estilos y JavaScript de presentación.

| Superficie | Controller / Action | Vista | Modelo | Estado, formulario y dependencias vigentes |
|---|---|---|---|---|
| Inicio | `Home/Index` GET | `Home/Index.cshtml` | `HomeFeaturedViewModel` | Ya usa `_StorefrontLayout`; vacío de destacados resuelto en la vista. |
| Catálogo | `Home/Shop` GET | `Home/Shop.cshtml` | `ShopViewModel` | Búsqueda y categoría por query string; productos y combos reales. No existen ordenamiento ni paginación en el contrato actual. |
| Producto | `Home/Detail/{id}` GET | `Home/Detail.cshtml` | `StoreProductViewModel` | Imagen única, precio y stock; formulario POST `Cart/Add` con antiforgery. No existen relacionados en el modelo. |
| Combo | `Home/ComboDetail/{id}` GET | `Home/ComboDetail.cshtml` | `StoreComboViewModel` | Componentes resumidos, precio y stock; formulario POST `Cart/AddCombo` con antiforgery. |
| Carrito | `Cart/Index` GET | `Cart/Index.cshtml` | `CartViewModel` | POST `Update`, `Remove` y `Add`; promociones, regalías y recomendaciones reales; estado vacío. |
| Checkout | `Cart/Checkout` GET/POST | `Cart/Checkout.cshtml` | `CheckoutViewModel` | Antiforgery, `OperationToken`, bindings actuales y `checkout.js`; respuesta inválida 422 y servicio 503 desde el controlador. |
| Confirmación | `Cart/Confirmation` GET | `Cart/Confirmation.cshtml` | `OrderConfirmationViewModel` | Datos de TempData posteriores al pedido; enlaces a tienda y portal para Cliente. |
| Mi cuenta | `ClientPortal/Index` GET | `ClientPortal/Index.cshtml` | `ClientPortalIndexViewModel` | Resumen del cliente, crédito opcional y pedidos; estado vacío. |
| Detalle de pedido | `ClientPortal/Detail/{id}` GET | `ClientPortal/Detail.cshtml` | `ClientPortalOrderDetailViewModel` | Estado real, líneas, comprobante opcional, garantía por línea entregada y POST `Cancel` con antiforgery. |
| Comprobante | `ClientPortal/Invoice/{id}` GET | `ClientPortal/Invoice.cshtml` | `ClientPortalInvoiceViewModel` | Documento web imprimible; no existe descarga binaria separada. |
| Estado de cuenta / crédito | `ClientPortal/Statement` GET | `ClientPortal/Statement.cshtml` | `ClientPortalStatementViewModel` | Crédito opcional, compras y tabla de pedidos; salida mediante impresión/guardar PDF del navegador. |
| Solicitar garantía | `ClientPortal/Warranty/{id}` GET/POST | `ClientPortal/Warranty.cshtml` | `WarrantyRequestFormViewModel` | Antiforgery, validación de motivo/descripción y ownership comprobado por backend. |
| Mis garantías | `ClientPortal/Warranties` GET | `ClientPortal/Warranties.cshtml` | `List<ClientWarrantyListItemViewModel>` | Estados reales y estado vacío; no existe acción cliente de detalle separada. |
| Perfil | `Profile/Edit` GET/POST | `Profile/Edit.cshtml` | `ProfileEditViewModel` | Antiforgery, validación y datos de contacto. |
| Login | `Account/Login` GET/POST | `Account/Login.cshtml` | `LoginViewModel` | `returnUrl`, validación, recordarme y recuperación. |
| Registro | `Account/Register` GET/POST | `Account/Registro.cshtml` | `RegistroViewModel` | Datos de cuenta, confirmación de contraseña y aceptación de términos. |
| Recuperación | `Account/ForgotPassword` GET/POST | `Account/ForgotPassword.cshtml` | `ForgotPasswordViewModel` | Solicitud de enlace con antiforgery y validación. |
| Restablecimiento | `Account/ResetPassword` GET/POST | `Account/ResetPassword.cshtml` | `ResetPasswordViewModel` | Token oculto, contraseña y confirmación. |

## Dependencias compartidas

- Layout Stage 2: `_StorefrontLayout.cshtml`.
- Mensajes: `_Stage2Messages.cshtml`.
- Iconos: `_DjjIconSprite.cshtml`, Phosphor Regular local.
- CSS: `tokens.css`, `base.css`, `components.css`, `storefront.css`, `utilities.css`.
- JavaScript: `wwwroot/js/stage2/layouts.js`; checkout conserva `wwwroot/js/checkout.js`.
- Validación cliente: `_ValidationScriptsPartial.cshtml` en formularios existentes.

## Límites funcionales encontrados

- `ShopViewModel` no contiene ordenamiento, total paginado, página actual ni tamaño de página; no se simulan controles que el backend no puede preservar.
- Producto y combo exponen una sola imagen y no incluyen relacionados; no se inventan galerías ni recomendaciones.
- El comprobante y el estado de cuenta solo ofrecen impresión del navegador; la interfaz lo nombra con precisión.
- Algunos casos inexistentes del portal redirigen con mensaje según el controlador vigente. Stage 2.2 no modifica esa semántica backend.
- `Account/AccesoDenegado` sirve a perfiles internos y cliente; permanece en el layout transversal heredado para no convertir un error global en una superficie exclusivamente Storefront.
