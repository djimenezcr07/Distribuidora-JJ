# Manual de uso del sistema

**Aplicación:** Supermercado Mayoreo – Licorera / Distribuidora  
**Versión revisada:** `main`, commit `fc1bd527aa184a0b7297c306325fa468caf28c8a`  
**Fecha de revisión:** 11 de agosto de 2026

## Alcance y lectura de la evidencia

Este manual se elaboró a partir de controladores, vistas, rutas convencionales MVC, filtros `AdminAuthorize`, permisos por código, ViewModels, migraciones y documentación funcional vigente. También se revisó la instancia Azure indicada, sin crear, modificar, eliminar, pagar ni enviar información.

Las etiquetas de evidencia significan:

- **Azure (lectura):** pantalla o ruta abierta en el despliegue, sin ejecutar una acción que alterase datos.
- **Código:** ruta, validación o autorización comprobada en esta revisión del repositorio.
- **Pendiente QA:** necesita una cuenta de ese perfil y datos de prueba para confirmar el resultado de extremo a extremo.

Los roles se administran dinámicamente desde **Administración > Seguridad > Roles**. La lista activa vista en Azure contiene: Administrador, Cliente, Empleado, Chofer, Vendedor, Cajero, Bodeguero, Facturador, Crédito y Cobro, Compras, Supervisor, Soporte, Auditor Interno y Gerente. No se encontró un rol activo independiente llamado **Bodega** ni **Financiero**; el código los trata como alias de menú en algunos casos, pero no deben asignarse ni documentarse como perfiles existentes hasta que se creen en Roles.

## 1. Acceso al sistema

- **MVC:** <https://web-trilogia-cursos-dev-cr01-bbeyeedbfjejcgau.centralus-01.azurewebsites.net/>
- **API / Swagger:** <https://api-trilogia-cursos-dev-cr01-haefhbgrd8dvcvc5.centralus-01.azurewebsites.net/swagger/index.html>
- **Navegadores recomendados:** versiones actuales de Edge, Chrome o Firefox, con JavaScript y cookies de sesión habilitados.
- **Inicio de sesión:** desde **Iniciar sesión** o `/Account/Login`, escriba correo y contraseña; **INGRESAR** crea la sesión y muestra los menús de su perfil. La casilla “Recordarme en este equipo” solo debe usarse en equipos confiables.
- **Registro:** desde **Registro** o `/Account/Register`; requiere nombre completo, correo, contraseña, confirmación y aceptar términos. El registro crea una cuenta de rol Cliente.
- **Recuperación:** en Login, seleccione **¿Olvidaste tu contraseña?**; ingrese el correo y pulse **ENVIAR ENLACE**. El mensaje no confirma si el correo existe. Abra el enlace recibido, ingrese y confirme la nueva contraseña, y pulse **CAMBIAR CONTRASEÑA**.
- **Redirección a Login:** la ruta exige sesión. Inicie sesión con el perfil autorizado y vuelva a abrir la opción; en checkout el sistema conserva la dirección de retorno.
- **“Acceso denegado”:** la sesión existe, pero el perfil no tiene el módulo o permiso exacto. No cambie la URL ni intente usar identificadores ajenos; solicite al Administrador que revise Roles > Permisos.
- **Cerrar sesión:** pulse **Cerrar sesión** en la franja superior. Es una acción POST protegida contra falsificación; después se elimina la sesión.

## 2. Matriz de permisos

| Rol activo | Puede acceder a | Acciones principales | Restricciones importantes | Evidencia |
| --- | --- | --- | --- | --- |
| Visitante | Inicio, tienda, detalle, carrito, contacto, login/registro | Buscar, filtrar, agregar al carrito | Checkout requiere sesión; no ve portal, chat ni administración | Código; inicio/tienda Azure |
| Cliente | Tienda, carrito, checkout, Mi cuenta | Pedidos propios, facturas/estado de cuenta, garantías propias, perfil | No accede a administración ni recursos de otros clientes | Código |
| Administrador | Panel y las 8 áreas de Administración, tienda, carrito, chat, venta móvil, asistente | Gestión integral sujeta a permisos; roles y permisos | Las escrituras siguen validando antiforgery, estado y permisos de acción | Azure (lectura) y código |
| Empleado | Mi portal, Mis jornadas, Mis boletas, venta móvil, asistente, chat | Tareas, solicitudes de días libres, jornada propia y venta | No administra roles ni registros ajenos | Código |
| Vendedor | Igual que Empleado, más Mi meta | Venta móvil/offline, pedidos propios y meta | Solo pedidos/boletas/jornadas propios; autorizaciones de ventas dependen del flujo | Código |
| Gerente | Finanzas, pedidos retenidos, tablero, ventas, vendedores, KPIs, asistente, chat | Revisar/autorizar pedidos retenidos, consultar reportes | Las acciones dependen de permisos como `PEDIDOS_AUTORIZAR_RECHAZAR` y reportes | Código |
| Chofer | Mis entregas, kilometraje, asistente, chat | Consultar rutas asignadas, registrar kilometraje/evidencias según autorización | No puede ver rutas o evidencias no asignadas | Código |
| Bodeguero | Chat; módulos concedidos por permisos | Preparar pedidos, inventario/movimientos si el perfil recibe permisos | El menú visible no sustituye los permisos del servidor | Azure (rol) y código |
| Cajero | Finanzas y chat | Liquidación de cobros; presupuestos/gastos si se le asignan permisos | No puede eludir los estados ni pagar gastos sin permiso | Código |
| Compras | Compras y chat | Proveedores, órdenes de compra, sugerencias e histórico de precios | Crear, recibir, cerrar y cancelar requieren permisos separados | Código |
| Supervisor | Chat; aprobación de jornadas cuando tenga `RRHH_JORNADAS_APROBAR` | Revisar jornadas | No ve ni modifica información fuera de sus permisos | Código |
| Facturador | Chat; facturación cuando el perfil tenga permiso | Consultar/generar factura y reenviar comprobante autorizado | Sin `FACTURACION_GENERAR` no genera ni reenvía | Código |
| Crédito y Cobro | Chat; créditos/cuentas por cobrar si se otorgan permisos | Seguimiento de crédito y cobro | No puede consultar datos ajenos sin el módulo Creditos | Código |
| Auditor Interno | Chat; auditoría si se otorgan permisos | Consultar trazabilidad | No modifica operaciones por el hecho de ser auditor | Azure (rol) y código |
| Soporte | Chat | Soporte interno y consultas autorizadas | No tiene privilegios administrativos implícitos | Azure (rol) y código |

## 3. Guía paso a paso por rol

### Visitante

| Paso | Acción | Ruta / botón | Resultado esperado |
| ---- | ------ | ------------ | ------------------ |
| 1 | Abrir catálogo | Inicio > **Tienda** (`/Home/Shop`) | Se muestran filtros, productos activos, precio, disponibilidad y combos vendibles. |
| 2 | Filtrar | Categoría o campo Buscar | El catálogo se limita al criterio; un producto inactivo, sin stock o combo no vendible no se ofrece. |
| 3 | Ver producto | **Ver** en una tarjeta | Abre `/Home/Detail/{id}` con detalle y opción de agregar. |
| 4 | Preparar compra | **Agregar al carrito** y luego **Carrito** | El carrito se conserva en la sesión; cantidad/precio se refrescan contra el servidor. |
| 5 | Intentar finalizar | **Finalizar compra** | Se redirige a Login con “Debes iniciar sesión para finalizar la compra.” |

### Cliente

| Paso | Acción | Ruta / botón | Resultado esperado |
| ---- | ------ | ------------ | ------------------ |
| 1 | Ingresar | `/Account/Login` > **INGRESAR** | Se muestra Mi cuenta y el perfil. |
| 2 | Comprar | Tienda > detalle/Agregar > Carrito > **Finalizar compra** | Se abre checkout; el carrito se revalida antes de presentar totales. |
| 3 | Completar envío | Checkout | Correo es de sesión; indique tipo de cliente, identificación, teléfono, provincia, cantón, distrito y dirección. Seleccione método de pago. |
| 4 | Confirmar | **Confirmar pedido** | Con stock y datos válidos, muestra “Pedido #… creado correctamente” y la confirmación. Un fallo de correo no revierte un pedido confirmado. |
| 5 | Consultar después | Mi cuenta > **Mis pedidos**, **Estado de cuenta** o **Mis garantías** | Solo se listan datos del cliente actual; factura y detalle se validan por propiedad. |
| 6 | Solicitar garantía | Mi cuenta > Mis garantías > nueva solicitud, sobre detalle elegible | Solo se admite para pedido propio entregado y sin garantía abierta duplicada. |
| 7 | Actualizar perfil | Nombre/rol en franja superior | Cambia datos permitidos del propio perfil; si no hay sesión vuelve a Login. |

### Administrador

| Paso | Acción | Ruta / botón | Resultado esperado |
| ---- | ------ | ------------ | ------------------ |
| 1 | Abrir panel | **Administración** > Panel (`/Admin`) | Dashboard con indicadores; no se modifican datos al consultarlo. |
| 2 | Gestionar inventario | Administración > Inventario | Productos, movimientos, transformación, combos, devoluciones, cuarentena y activos. Crear/editar exige campos válidos y permisos. |
| 3 | Gestionar venta | Administración > Ventas y Pedidos | Pedidos, facturación, cuentas por cobrar, promociones y garantías. Cambios de estado son POST protegidos. |
| 4 | Gestionar personal | Administración > RR. HH. / Seguridad | Empleados, departamentos, jornadas, planilla, roles, permisos, documentos y auditoría. |
| 5 | Asignar acceso | Seguridad > Roles > editar; Seguridad > Permisos | Guarde el perfil y después los permisos. El permiso exacto controla las operaciones sensibles. |
| 6 | Administrar departamentos de chat | Chat > **Administrar departamentos** (`/Chat`) | Crea/edita departamentos o miembros solo con `CHAT_DEPARTAMENTOS_GESTIONAR`. |

### Empleado

| Paso | Acción | Ruta / botón | Resultado esperado |
| ---- | ------ | ------------ | ------------------ |
| 1 | Abrir portal | **Mi portal** (`/EmployeePortal`) | Tareas asignadas y formulario de solicitud de días libres. |
| 2 | Actualizar tarea | Seleccione Pendiente / En proceso / Completada > **Actualizar** | Se actualiza solo una tarea autorizada. |
| 3 | Pedir días libres | Fecha inicio, fecha fin, tipo con/sin goce y motivo > **Enviar solicitud** | La solicitud queda para revisión; las reglas de fechas se validan en el servidor. |
| 4 | Registrar jornada | **Mis jornadas** | Guarda/solicita la jornada propia; el supervisor aprueba desde el módulo autorizado. |
| 5 | Consultar boleta | **Mis boletas** > detalle/descarga | Solo expone boletas del empleado en sesión. |
| 6 | Vender | **Venta móvil** | Elija cliente, identificación, entrega, dirección, observaciones y cantidades. |

### Vendedor

| Paso | Acción | Ruta / botón | Resultado esperado |
| ---- | ------ | ------------ | ------------------ |
| 1 | Usar portal y jornadas | **Mi portal** / **Mis jornadas** | Ve sus tareas, solicitudes y registros propios. |
| 2 | Registrar venta | **Venta móvil** | Crea o guarda offline un pedido con cliente, entrega y cantidades válidas. |
| 3 | Ver progreso | **Mi meta** | Consulta su meta de ventas; no ve metas de otros vendedores. |
| 4 | Consultar boleta | **Mis boletas** | Ve o descarga únicamente sus propias boletas. |

### Gerente

| Paso | Acción | Ruta / botón | Resultado esperado |
| ---- | ------ | ------------ | ------------------ |
| 1 | Gerente: revisar retenciones | **Pedidos retenidos** > abrir pedido > Aprobar o Rechazar | Solo un perfil con `PEDIDOS_AUTORIZAR_RECHAZAR` puede decidir; el rechazo requiere motivo. |
| 2 | Gerente: analizar | Tablero, Ventas, Vendedores o KPIs | Aplica filtros y permite impresión/CSV en los reportes permitidos. |

### Chofer

| Paso | Acción | Ruta / botón | Resultado esperado |
| ---- | ------ | ------------ | ------------------ |
| 1 | Consultar asignación | **Mis entregas** > ruta asignada | Solo ve entregas propias; puede registrar evidencia autorizada. |
| 2 | Registrar kilometraje | **Kilometraje** > abrir/cerrar registro | El sistema valida el estado del registro y el valor final. |
| 3 | Pedir orientación | **Asistente** | Recibe ayuda basada en reglas de acuerdo con su rol. |

### Bodeguero

| Paso | Acción | Ruta / botón | Resultado esperado |
| ---- | ------ | ------------ | ------------------ |
| 1 | Consultar trabajo interno | Chat y módulos concedidos | Solo ve conversaciones autorizadas. |
| 2 | Preparar/operar inventario | Módulo asignado por el Administrador | Puede manejar movimientos o pedidos solo con los permisos de inventario correspondientes. |

### Cajero

| Paso | Acción | Ruta / botón | Resultado esperado |
| ---- | ------ | ------------ | ------------------ |
| 1 | Abrir liquidación | Finanzas > **Liquidación de cobros** | Lista únicamente los cobros/rutas que el módulo permita. |
| 2 | Completar liquidación | Formulario > Guardar/Liquidar | Valida importe y estado; no utilice información productiva para pruebas. |

### Compras

| Paso | Acción | Ruta / botón | Resultado esperado |
| ---- | ------ | ------------ | ------------------ |
| 1 | Gestionar proveedor | Compras > **Proveedores** | Consulta/guarda proveedores según permisos de ver o gestionar. |
| 2 | Crear orden | Compras > **Órdenes de compra** > Crear | Elija proveedor activo, productos, cantidad y precio; se crea sin duplicar token de operación. |
| 3 | Recibir/cerrar | Detalle de la orden | Recepción, cierre y cancelación requieren permisos separados y estado permitido. |

### Facturador

| Paso | Acción | Ruta / botón | Resultado esperado |
| ---- | ------ | ------------ | ------------------ |
| 1 | Consultar factura | Administración > Facturación | Ve documentos que el módulo permite. |
| 2 | Generar o reenviar | Detalle > Generar/Reenviar | Solo procede con `FACTURACION_GENERAR`; el comprobante usa el total confirmado. |

### Crédito y Cobro

| Paso | Acción | Ruta / botón | Resultado esperado |
| ---- | ------ | ------------ | ------------------ |
| 1 | Revisar cartera | Administración > Créditos o Cuentas por cobrar | Consulta la información permitida por el módulo Creditos. |
| 2 | Abrir detalle | Fila > Detalle | No obtiene datos de clientes no autorizados. |

### Supervisor

| Paso | Acción | Ruta / botón | Resultado esperado |
| ---- | ------ | ------------ | ------------------ |
| 1 | Revisar jornada | Módulo de Jornadas | Con `RRHH_JORNADAS_APROBAR`, revisa los registros disponibles. |
| 2 | Aprobar o rechazar | Acción de la jornada | La transición se registra y no depende solo del menú. |

### Auditor Interno

| Paso | Acción | Ruta / botón | Resultado esperado |
| ---- | ------ | ------------ | ------------------ |
| 1 | Consultar trazabilidad | Administración > Auditoría, cuando tenga el módulo | Ve eventos de auditoría autorizados sin alterar la operación original. |
| 2 | Comunicarse | **Chat** | Accede únicamente a chats/departamentos autorizados. |

### Soporte

| Paso | Acción | Ruta / botón | Resultado esperado |
| ---- | ------ | ------------ | ------------------ |
| 1 | Atender consulta interna | **Chat** | Puede abrir conversaciones permitidas. |
| 2 | Usar funciones adicionales | Módulo expresamente asignado | El rol no da privilegios administrativos implícitos. |

### Roles de soporte: chat y autorización

| Paso | Acción | Ruta / botón | Resultado esperado |
| ---- | ------ | ------------ | ------------------ |
| 1 | Abrir chat autorizado | **Chat** > Chats privados o Departamentos | Puede buscar/abrir conversaciones permitidas; no debe aparecer ni acceder a departamentos ajenos. |
| 2 | Comprobar denegación | Ruta de otro módulo | El sistema redirige a Login si no hay sesión o a Acceso denegado si falta permiso. |

## 4. Guía por módulo

### Tienda, carrito y pedido

La tienda permite `categoria` y `buscar`. Al agregar producto o combo, el servidor limita la cantidad al stock vigente. El carrito vuelve a consultar catálogo, elimina ítems ya no vendibles y puede mostrar promociones vigentes y recomendaciones explicables. En checkout son obligatorios provincia, cantón, distrito, dirección, identificación, correo disponible y método de pago válido. Métodos disponibles: efectivo contra entrega, SINPE Móvil simulado, tarjeta demo y transferencia simulada. Los precios, stock, promociones y total se vuelven a validar de forma atómica al confirmar. Errores habituales: “Tu carrito está vacío”, “El producto no está disponible”, “No hay stock suficiente…” o “El intento de compra expiró…”.

### Portal del cliente, comprobantes y créditos

El portal concentra pedidos, detalle, factura, estado de cuenta y garantías. Toda consulta usa la identidad de sesión, no el identificador enviado por la URL. La administración de pedidos puede cambiar estado; facturación genera desde un pedido elegible y puede reenviar comprobante con permiso. Cuentas por cobrar, créditos y consultas administrativas requieren el módulo correspondiente.

### Inventario, compras, proveedores y promociones

En **Inventario > Crear**: nombre, categoría, precio, stock inicial y stock mínimo son obligatorios; descripción e imagen son opcionales. También se puede activar/destacar, registrar movimientos, transformar stock y gestionar combos. Las imágenes se validan mediante servicio de almacenamiento. En Compras, una orden requiere proveedor activo, al menos una línea seleccionada, cantidad mínima 1 y precio mayor que 0; el token de operación evita duplicados. Promociones se crean/editan/inactivan y sus segmentos se asignan solo con permiso.

### Venta móvil y pedidos offline

Venta móvil requiere cliente, identificación y una línea con cantidad válida; se permite definir entrega por vendedor, retiro o envío. **Guardar offline** conserva el pedido local con un GUID y **Sincronizar pendientes** lo envía cuando haya conexión; no debe duplicarse si se reintenta. Confirme el mensaje de confirmación o de pedido retenido antes de informar la venta al cliente. Este flujo no fue confirmado con perfil Vendedor en Azure.

### Empleados, RR. HH., asistencia y boletas

Administrador gestiona empleados y departamentos con `EMPLEADOS_VER`, `EMPLEADOS_CREAR` y `EMPLEADOS_EDITAR`. Empleado/Vendedor usa Mi portal, solicitudes y sus jornadas/boletas. El responsable no debe aprobar su propio registro cuando la regla aplicable exige separación. PaySlips permite consultar/descargar las propias; gestión y envío se reservan a `PLANILLA_BOLETAS_GESTIONAR`.

### Chat y asistente

Los roles activos listados pueden abrir chat. Chats privados, departamentos, búsqueda e historial aplican pertenencia del usuario; el contenido se presenta como texto. Publicar en departamento requiere que sea miembro y tenga permiso de publicación; administrar departamentos exige `CHAT_DEPARTAMENTOS_GESTIONAR`. El asistente es **conversacional basado en reglas e interpretación de intenciones**: responde preguntas y acciones rápidas según rol, con límites de tasa. No es IA externa ni cambia precios, cantidades o permisos automáticamente.

### Planilla configurable

Acceda a `/Payroll` con `PLANILLA_VER`. Para una regla: código único en mayúsculas/guiones bajos, nombre, tipo ingreso/deducción, cálculo, valor, vigencia y fuente son requeridos; tope es opcional. Para período: frecuencia quincenal/mensual, fechas, factor salarial mayor que 0 y hasta 1, y fuente. Calcular solicita ID de período, ID de empleado y comisiones; el cálculo es idempotente. Aprobar, pagar y revertir requieren permisos distintos, estado válido, versión de fila vigente y, para revertir, motivo. No se deben crear periodos, calcular, aprobar, pagar ni revertir en productivo durante pruebas manuales sin datos QA reversibles.

### Documentos, alertas, presupuestos, gastos y comparativa

Documentos digitales requieren `DOCUMENTOS_VER`; crear, editar, reemplazar y activar/desactivar requiere `DOCUMENTOS_GESTIONAR`. La carga privada valida tipo/firma/tamaño y no se publica bajo `wwwroot`. Generar alertas y atenderlas usa permisos separados. Presupuesto: año, departamento, categoría inicial y monto anual son obligatorios; se crea borrador, se distribuye, presenta, aprueba/rechaza y cierra según permisos y estado. Gastos validan importe del servidor, comprobante y transiciones Registrado/Aprobado/Rechazado/Pagado/Anulado; exceder presupuesto requiere permiso explícito. Comparativa permite filtros, detalle, impresión y CSV con neutralización de fórmulas.

### Logística, flota, activos y reclamos

Administración agrupa rutas/entregas, tablero, vehículos, kilometraje, mantenimiento, alertas, comodatos, activos, devoluciones/cuarentena y reclamos. Crear/editar/operar requiere los permisos `RUTAS_GESTIONAR`, `ENTREGAS_*`, `FLOTA_*`, `ACTIVOS_GESTIONAR`, devoluciones o servicio al cliente que correspondan. Las evidencias de entrega se consultan por autorización y las rutas del chofer se restringen a asignación. No se confirmó en Azure con cuentas específicas de Chofer/Bodeguero.

### API / Swagger

Swagger está disponible en Azure y expone Auth y Products. Uso técnico autorizado y seguro: utilice únicamente GET públicos (`/`, `/health`, `/api/products`, `/api/productos`, categorías, destacados y detalle) con datos de prueba. Auth incluye login, registro, recuperación y reset, pero no emite JWT/API key/cookie compartida; no use su respuesta como autorización administrativa. No hay endpoints públicos para pedidos, inventario administrativo, facturación, clientes, roles o permisos. No pegue credenciales reales ni ejecute POST de registro/reset sin autorización.

## 5. Casos frecuentes

| Situación | Qué hacer |
| --- | --- |
| No puedo iniciar sesión | Confirme correo, contraseña y mayúsculas; use recuperación si corresponde. El sistema da mensaje genérico para no revelar cuentas. Si persiste, reporte hora, ruta y mensaje sin enviar contraseña. |
| No veo una opción en el menú | Cierre y abra sesión para refrescar el perfil. Si sigue ausente, el rol o permiso no la habilita; solicite revisión en Roles > Permisos. |
| No tengo permiso para una acción | No intente modificar la URL. Identifique módulo/acción y pida el permiso exacto; por ejemplo, ver gastos no concede pagar gastos. |
| No veo mis productos, pedidos, tareas o mensajes | Revise filtros, estado y sesión correcta. Los recursos de otro usuario no se muestran por diseño. |
| El chat no permite enviar | Verifique que sea miembro del departamento y tenga publicación habilitada; use chat privado si corresponde. El administrador gestiona membresías. |
| La planilla no permite calcular, aprobar o pagar | Verifique período/empleado, estado del cálculo, versión actual y permiso específico. No se puede pagar sin aprobación válida ni revertir sin motivo. |
| No recibí recuperación por correo | Revise spam y espere el tiempo de entrega. El mensaje sigue siendo genérico; solicite a soporte revisar configuración sin compartir el enlace/token. |
| Cómo reportar un error | Anote ruta, hora, perfil (sin nombre/correo), pasos, resultado esperado, mensaje visible y captura sin datos personales. No envíe contraseñas, tokens ni comprobantes reales. |

## 6. Pruebas realizadas

| Rol / módulo | Prueba | Resultado | Tipo de evidencia |
| ------------ | ------ | --------- | ----------------- |
| Administrador | Inicio, menú de sesión y catálogo | Cargaron; se observó menú Administración, Tienda, Carrito, Chat, Venta móvil y Asistente | Azure (lectura) |
| Roles | Listado de perfiles activos | Se confirmaron los 14 roles enumerados en este manual; no se modificó ninguno | Azure (lectura) |
| Tienda | `/Home/Shop` | Cargó filtros, combos disponibles, productos y formularios de agregar al carrito | Azure (lectura) |
| Carrito | `/Cart` | Cargó “Revisá tu pedido” y estado vacío, sin agregar productos | Azure (lectura) |
| Administración | `/Admin` | Cargó panel de administrador | Azure (lectura) |
| Planilla | `/Payroll` | Cargó reglas, período, cálculo y acciones de aprobación/pago/reversión; no se enviaron formularios | Azure (lectura) |
| Chat | `/Chat` | Cargó administración de departamentos y formularios de gestión; no se modificó membresía | Azure (lectura) |
| Venta móvil | `/SellerOrders` | Cargó formulario y controles offline; no se creó ni sincronizó pedido | Azure (lectura) |
| API | Swagger | Cargó UI y operaciones Auth, Products, raíz y health | Azure (lectura) |
| Autorización/validaciones | Revisión de filtros, controladores y ViewModels | Rutas sensibles usan rol/módulo y, donde aplica, permiso por código, antiforgery y validación de propiedad/estado | Código |

## 7. Pendientes reales

- Login, registro, recuperación y cierre de sesión con una cuenta QA autorizada, sin exponer credenciales.
- Checkout completo, confirmación, correo y comprobante con datos reversibles QA; no se efectuó compra.
- Portal Cliente, garantía propia, factura y estado de cuenta con perfil Cliente.
- Venta móvil/offline y Mi meta con perfil Vendedor; tareas, permisos, jornada y boletas con Empleado.
- Rutas, evidencias y kilometraje con Chofer; preparación/inventario con Bodeguero; liquidación con Cajero; compras con perfil Compras.
- Denegaciones positivas y negativas de cada permiso granular, incluida pertenencia de chat, recursos de otros usuarios y antiforgery.
- Flujos de documentos/alertas, presupuesto/gastos/comparativa y toda escritura financiera con datos QA y roles separados.
- Estados completos de planilla, envío de boletas, SignalR/búsqueda paginada de chat, correos, promociones, concurrencia de stock y operación de API Auth.

**Flujos documentados:** 43 flujos paso a paso y módulos operativos, más restricciones y casos de error.  
**Importante:** una opción que el menú muestra no equivale por sí sola a autorización de escritura; el servidor vuelve a verificar sesión, rol, módulo, permiso, propiedad y estado de la operación.
