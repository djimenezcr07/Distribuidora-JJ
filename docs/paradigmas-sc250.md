# 1. Paradigmas de programación en DistribuidoraJJ

**Curso:** SC-250 Paradigmas de Programación

**Proyecto:** DistribuidoraJJ / Licorera La Bodega

**Solución:** `Proyecto_Final.slnx`

**Estado documental:** 30 de julio de 2026

## 2. Contexto académico

Este documento identifica cómo una misma solución de software evidencia exactamente cuatro paradigmas de programación: orientado a objetos, imperativo, funcional y declarativo. El propósito no es clasificar toda la aplicación bajo un único paradigma, sino demostrar que cada enfoque resuelve un tipo de problema diferente dentro de DistribuidoraJJ.

Las evidencias proceden del código vigente del repositorio. Los fragmentos son breves, conservan los nombres reales y se acompañan de sus rutas y líneas aproximadas. Una construcción aislada, como una expresión LINQ o una consulta mediante ADO.NET, no se considera suficiente por sí sola: la clasificación toma en cuenta el manejo del estado, los efectos secundarios y la forma en que se expresa la solución.

El alcance académico se limita a los cuatro paradigmas indicados. No se incorporan paradigmas adicionales.

## 3. Descripción resumida de DistribuidoraJJ

DistribuidoraJJ es una aplicación universitaria para administrar y vender productos de una distribuidora. Incluye catálogo público, combos, carrito, checkout, pedidos, inventario, facturación, presupuestos, gastos y reportes administrativos.

Para este análisis se seleccionaron cuatro módulos concretos:

- Administración y venta de combos.
- Checkout y creación transaccional del pedido.
- Inteligencia y normalización de inventario.
- Reporte financiero de presupuesto contra gasto real.

La selección permite mostrar cada paradigma con una evidencia principal distinta y evita atribuir dos paradigmas al mismo fragmento.

## 4. Arquitectura general del sistema

La solución contiene tres proyectos:

- `Proyecto_Final/`: aplicación ASP.NET Core MVC con controladores, servicios, ViewModels y vistas Razor.
- `Proyecto_FinalAPI/`: API pública para autenticación básica y consulta de productos.
- `Proyecto_Final.Tests/`: pruebas automatizadas xUnit.

Los módulos estudiados siguen, en términos generales, este recorrido:

```text
Solicitud HTTP
    -> Controller
        -> Service / interfaz de servicio
            -> ADO.NET
                -> procedimiento o vista de SQL Server
        -> ViewModel
    -> Vista Razor o respuesta HTTP
```

Esta separación permite que la capa web coordine la interacción, los servicios encapsulen operaciones y SQL Server conserve las reglas autoritativas que requieren consistencia transaccional o agregación de datos.

## 5. Tecnologías utilizadas

- .NET 9 y C#.
- ASP.NET Core MVC.
- Razor Views fuertemente tipadas.
- Inyección de dependencias integrada de ASP.NET Core.
- ADO.NET mediante `Microsoft.Data.SqlClient`.
- SQL Server y T-SQL.
- LINQ para transformación de colecciones en memoria.
- xUnit para pruebas automatizadas.
- LocalDB para verificaciones SQL aisladas documentadas en el repositorio.

Las tecnologías no se equiparan automáticamente con un paradigma. Por ejemplo, LINQ puede utilizarse dentro de código con efectos secundarios, y ADO.NET es un mecanismo imperativo de acceso a datos aunque ejecute una consulta declarativa en SQL Server.

## 6. Matriz general de paradigmas

| Paradigma | Módulo | Problema resuelto | Tecnología | Archivo | Clase o procedimiento | Evidencia | Justificación | Prueba existente | Prueba pendiente |
|---|---|---|---|---|---|---|---|---|---|
| Orientado a objetos | Administración y venta de combos | Separar contrato, acceso a datos, coordinación web, validación y presentación de combos | C#, ASP.NET Core MVC, DI, Razor | `Proyecto_Final/Services/ComboDbService.cs`; `Proyecto_Final/Controllers/CombosController.cs`; `Proyecto_Final/Models/Admin/ComboViewModels.cs`; `Proyecto_Final/Program.cs` | `IComboDbService`, `ComboDbService`, `CombosController`, `ComboFormViewModel`, `StoreComboViewModel` | Interfaz, implementación, composición, encapsulamiento de dependencias, herencia de `Controller` e inyección de dependencias | Los objetos colaboran mediante contratos y cada clase concentra una responsabilidad reconocible | Validación de combos y atributos de seguridad en `Sprint4DomainTests` y `Sprint4ControllerSecurityTests` | Prueba de colaboración del controlador con un doble de `IComboDbService` |
| Imperativo | Checkout y creación transaccional del pedido | Ejecutar en orden la validación, confirmación, persistencia, correo y limpieza del carrito | C#, ASP.NET Core MVC, ADO.NET; T-SQL complementario | `Proyecto_Final/Controllers/CartController.cs`; `Proyecto_Final/Services/StoreDbService.cs` | `Checkout`, `BuildCartViewModelAsync`, `RefreshCartItemsAsync`, `CreateOrderWithPromotionsAsync`; complemento `sp_Store_CreateOrderWithPromotions` | Asignaciones, condiciones, ciclos, excepciones y efectos ejecutados paso a paso | El orden de las instrucciones y los cambios de estado determina el resultado del flujo | Pruebas del payload y comprobante; verificaciones LocalDB de checkout, idempotencia y concurrencia | Pruebas directas del POST para sesión, validación, fallo SMTP, limpieza y redirección |
| Funcional | Inteligencia y normalización de inventario | Convertir resultados parciales o duplicados en una serie completa y ordenada de doce meses | C# y LINQ sobre objetos en memoria | `Proyecto_Final/Models/Admin/InventoryIntelligenceViewModels.cs` | `InventoryIntelligencePolicy.NormalizeTwelveMonths` | `Where`, `GroupBy`, `ToDictionary`, `Sum`, `Range` y `Select`; creación de una nueva colección sin modificar la entrada | La salida depende de los argumentos y se obtiene mediante composición de transformaciones | `SeasonalTrend_AlwaysReturnsTwelveUniqueOrderedMonths` | No mutación, independencia del orden, meses inválidos, entrada nula y determinismo repetido |
| Declarativo | Reporte financiero presupuesto contra gasto real | Expresar filtros, relaciones, agregaciones, clasificación, serie mensual y paginación del reporte | SQL Server y T-SQL; C# como consumidor | `database/migrations/0010_operating_expenses_alignment.sql`; `database/migrations/0011_budget_actual_comparison.sql` | `vw_OperatingExpenseImpact`, `sp_BudgetComparison_Dashboard` | `SELECT`, `JOIN`, `WHERE`, `SUM`, `CASE`, `OUTER APPLY`, CTE, `ORDER BY`, `OFFSET` y `FETCH` | SQL describe qué resultado se necesita y delega al motor el plan físico de ejecución | Validación sintáctica y QA manual documentado; pruebas C# de fórmulas relacionadas | Prueba aislada de resultados del procedimiento 0011 con filtros, anulaciones, doce meses y paginación |

## 7. Evidencia individual de cada paradigma

### 7.1. Paradigma orientado a objetos

#### Definición

La programación orientada a objetos organiza el sistema como objetos que combinan estado, comportamiento y responsabilidades. Emplea abstracción, encapsulamiento, composición, interfaces y, cuando resulta útil, herencia o polimorfismo.

#### Problema que resuelve

El módulo de combos necesita separar las operaciones disponibles, la implementación de acceso a datos, la coordinación HTTP, la validación de formularios y la presentación en vistas. Sin esa separación, el controlador tendría que conocer directamente todos los detalles de SQL y de la construcción de los modelos.

#### Módulo

Administración y venta de combos.

#### Archivos y elementos involucrados

| Ruta | Elemento | Responsabilidad |
|---|---|---|
| `Proyecto_Final/Services/ComboDbService.cs` | `IComboDbService` | Declara el contrato para listar, consultar, crear, activar/inactivar y publicar combos. |
| `Proyecto_Final/Services/ComboDbService.cs` | `ComboDbService` | Implementa el contrato y encapsula el acceso a procedimientos almacenados. |
| `Proyecto_Final/Controllers/CombosController.cs` | `CombosController` | Coordina solicitudes administrativas y depende de `IComboDbService`. |
| `Proyecto_Final/Models/Admin/ComboViewModels.cs` | `ComboFormViewModel` | Representa y valida la entrada para crear un combo. |
| `Proyecto_Final/Models/Admin/ComboViewModels.cs` | `StoreComboViewModel` | Representa el combo público y calcula su disponibilidad. |
| `Proyecto_Final/Program.cs` | Registro DI | Vincula `IComboDbService` con `ComboDbService`. |
| `Proyecto_Final/Views/Combos/Index.cshtml` | Vista tipada | Recibe `IReadOnlyList<ComboListItemViewModel>`. |
| `Proyecto_Final/Views/Combos/Create.cshtml` | Vista tipada | Recibe `ComboFormViewModel`. |
| `Proyecto_Final/Views/Combos/Detail.cshtml` | Vista tipada | Recibe `ComboDetailViewModel`. |
| `Proyecto_Final/Views/Home/Shop.cshtml` | Vista tipada | Presenta productos y combos mediante `ShopViewModel`. |
| `Proyecto_Final/Views/Home/ComboDetail.cshtml` | Vista tipada | Recibe `StoreComboViewModel` para la venta pública. |

#### Entradas

- Identificador de combo.
- Datos de `ComboFormViewModel`: nombre, descripción, precio y productos seleccionados.
- Identidad del usuario administrativo.
- Texto de búsqueda para el catálogo público.
- `CancellationToken` de la solicitud.

#### Proceso

1. El controlador recibe la solicitud.
2. ASP.NET Core construye el ViewModel y ejecuta su validación.
3. El controlador invoca el contrato `IComboDbService`.
4. `ComboDbService` ejecuta el procedimiento correspondiente y crea objetos de salida.
5. El controlador entrega esos objetos a una vista fuertemente tipada.

#### Salidas

- Listados y detalles administrativos.
- Identificador del combo creado.
- Modelos públicos para tienda y detalle.
- Vista Razor renderizada o resultado HTTP como `NotFound`/redirección.

#### Fragmento real

Ruta: `Proyecto_Final/Services/ComboDbService.cs`, líneas aproximadas 8-18.

```csharp
public interface IComboDbService
{
    Task<IReadOnlyList<ComboListItemViewModel>> GetAdminCombosAsync(CancellationToken cancellationToken = default);
    Task<ComboDetailViewModel?> GetDetailAsync(int comboId, CancellationToken cancellationToken = default);
    Task<int> CreateAsync(ComboFormViewModel model, int userId, string userName, CancellationToken cancellationToken = default);
    Task ToggleStatusAsync(int comboId, int userId, string userName, CancellationToken cancellationToken = default);
    Task<IReadOnlyList<StoreComboViewModel>> GetStoreCombosAsync(string? search, CancellationToken cancellationToken = default);
    Task<StoreComboViewModel?> GetStoreComboAsync(int comboId, CancellationToken cancellationToken = default);
}

public sealed class ComboDbService : IComboDbService
```

Registro relacionado, `Proyecto_Final/Program.cs`, línea aproximada 159:

```csharp
builder.Services.AddScoped<IComboDbService, ComboDbService>();
```

#### Explicación línea por línea

1. `public interface IComboDbService` define una abstracción independiente del controlador.
2. `GetAdminCombosAsync` y `GetDetailAsync` expresan las lecturas administrativas sin exponer `SqlDataReader`.
3. `CreateAsync` agrupa los datos y la identidad necesarios para crear un combo.
4. `ToggleStatusAsync` representa el cambio de estado como una operación del contrato.
5. `GetStoreCombosAsync` y `GetStoreComboAsync` separan el catálogo público del detalle administrativo.
6. `ComboDbService : IComboDbService` declara que la clase concreta cumple el contrato.
7. `AddScoped<IComboDbService, ComboDbService>()` permite que el contenedor construya e inyecte la implementación por solicitud.

#### Características evidenciadas

- Abstracción mediante `IComboDbService`.
- Polimorfismo de implementación a través de inyección de dependencias.
- Encapsulamiento de la cadena de conexión y comandos dentro del servicio.
- Herencia de infraestructura en `CombosController : Controller`.
- Composición de `ComboDetailViewModel` con líneas de detalle.
- Validación asociada al objeto mediante `IValidatableObject`.
- Propiedad calculada `StoreComboViewModel.Disponible`.
- Separación de responsabilidades entre controlador, servicio, modelos y vistas.

#### Por qué es adecuado

El módulo posee varias representaciones y operaciones relacionadas, pero con responsabilidades diferentes. El enfoque orientado a objetos permite cambiar la implementación del servicio o probar un consumidor mediante otro objeto que respete el mismo contrato, sin trasladar el acceso a datos a las vistas o al controlador.

#### Relación con los otros paradigmas

- El controlador orientado a objetos puede ejecutar un flujo imperativo.
- Un método de una clase puede delegar cálculos a funciones puras.
- El servicio encapsula el acceso a procedimientos declarativos, pero el procedimiento SQL no se convierte por ello en orientación a objetos.

#### Pruebas existentes

- `Proyecto_Final.Tests/Sprint4DomainTests.cs`
  - `Combo_RequiresAtLeastOneSelectedComponent`.
  - `Combo_RejectsDuplicateProducts`.
  - `StoreCombo_AvailabilityRequiresStockAndComponents`.
  - `StoreCombo_InactiveOrMissingComponent_IsNotAvailable`.
- `Proyecto_Final.Tests/Sprint4ControllerSecurityTests.cs`
  - `NewSprint4Controllers_RequireExactReadPermission`.
  - `NewSprint4Writes_RequireExactPermission`.
  - `NewSprint4Writes_RequireAntiforgery`.

#### Pruebas pendientes

- Sustituir `IComboDbService` por un doble y comprobar que `CombosController.Index` delega y entrega el modelo correcto.
- Verificar que `Create` repuebla el listado de productos cuando `ModelState` es inválido.
- Verificar resultados `NotFound` y redirecciones sin conexión real a SQL Server.

#### Posibles preguntas del profesor

**Pregunta:** ¿Dónde está el polimorfismo si solo existe una implementación del servicio?

**Respuesta sugerida:** El consumidor trabaja con el tipo `IComboDbService`, no con la implementación concreta. El contenedor selecciona `ComboDbService`, pero podría registrar otra implementación que mantenga el contrato sin cambiar el controlador.

**Pregunta:** ¿Los ViewModels con propiedades públicas demuestran encapsulamiento fuerte?

**Respuesta sugerida:** Demuestran encapsulamiento parcial y separación de representación, pero no son un modelo de dominio rico. La evidencia más fuerte está en el contrato del servicio, sus dependencias privadas y la distribución de responsabilidades.

**Pregunta:** ¿Los procedimientos usados por `ComboDbService` son orientación a objetos?

**Respuesta sugerida:** No. Son colaboradores de persistencia. La evidencia orientada a objetos está en las clases, interfaces, composición e inyección de C#.

### 7.2. Paradigma imperativo

#### Definición

La programación imperativa expresa cómo alcanzar un resultado mediante una secuencia de instrucciones que consultan o modifican estado. Son características típicas las asignaciones, condiciones, ciclos, llamadas con efectos secundarios y manejo explícito del control de flujo.

#### Problema que resuelve

Finalizar una compra requiere respetar un orden: refrescar el carrito, normalizar entradas, autenticar, validar, crear el pedido, construir la confirmación, intentar enviar el correo, limpiar la sesión y responder al navegador. Cambiar ese orden puede producir resultados incorrectos.

#### Módulo

Checkout y creación transaccional del pedido.

#### Archivos y elementos involucrados

| Ruta | Elemento | Responsabilidad |
|---|---|---|
| `Proyecto_Final/Controllers/CartController.cs` | `Checkout(CheckoutViewModel)` | Orquesta el POST completo del checkout. |
| `Proyecto_Final/Controllers/CartController.cs` | `BuildCartViewModelAsync` | Refresca el carrito y prepara las promociones de presentación. |
| `Proyecto_Final/Controllers/CartController.cs` | `RefreshCartItemsAsync` | Recorre líneas, vuelve a consultar productos/combos y descarta las no vendibles. |
| `Proyecto_Final/Services/StoreDbService.cs` | `CreateOrderWithPromotionsAsync` | Construye parámetros, ejecuta el checkout autoritativo y lee sus resultados. |
| `database/migrations/0012_inventory_combos_transformations_intelligence.sql` | `sp_Store_CreateOrderWithPromotions` | Evidencia complementaria de transacción, bloqueos y mutaciones ordenadas. |
| `Proyecto_Final/Views/Cart/Checkout.cshtml` | Vista de entrada | Presenta el formulario de compra. |
| `Proyecto_Final/Views/Cart/Confirmation.cshtml` | Vista de salida | Presenta el pedido confirmado. |

#### Entradas

- `CheckoutViewModel` enviado por formulario.
- Carrito serializado en sesión.
- `UserId`, correo y nombre almacenados en sesión.
- Productos y combos vigentes consultados al servidor.
- Token idempotente `OperationToken`.

#### Proceso

1. Reconstruir el carrito desde datos vigentes.
2. Normalizar tipo de entrega, método y referencia de pago.
3. Comprobar sesión y carrito no vacío.
4. Agregar errores para dirección, identificación, correo, método y token.
5. Detener el flujo si `ModelState` no es válido.
6. Invocar `CreateOrderWithPromotionsAsync`.
7. Unir líneas confirmadas y regalías devueltas por SQL.
8. Construir `OrderConfirmationViewModel`.
9. Intentar enviar el comprobante sin revertir el pedido si SMTP falla.
10. Limpiar el carrito y redirigir a confirmación.
11. Transformar errores de inventario o errores inesperados en respuestas controladas.

#### Salidas

- Pedido confirmado con `PedidoId` y total autoritativo.
- Líneas confirmadas y regalías.
- Confirmación temporal serializada.
- Carrito eliminado de sesión.
- Vista con errores o redirección a `Confirmation`.

#### Fragmento real

Ruta: `Proyecto_Final/Controllers/CartController.cs`, líneas aproximadas 325-350.

```csharp
if (!ModelState.IsValid)
{
    return View(model);
}

try
{
    var usuarioId =
        HttpContext.Session.GetInt32("UserId") ?? 0;

    var order = await _storeDbService.CreateOrderWithPromotionsAsync(
        usuarioId,
        model,
        model.Cart.Items,
        HttpContext.RequestAborted);

    var confirmedItems = order.Items.Concat(order.Gifts).ToList();

    var confirmacion = new OrderConfirmationViewModel
    {
        PedidoId = order.PedidoId,
        TipoEntrega = model.TipoEntrega,
        DireccionEntrega = model.DireccionEntrega,
        Total = order.Total,
        Items = confirmedItems
    };
```

#### Explicación línea por línea

1. El `if` comprueba el estado acumulado de validación y detiene el flujo si hay errores.
2. `return View(model)` conserva la entrada y evita ejecutar cualquier efecto de compra.
3. `try` delimita el bloque que puede producir errores de datos o infraestructura.
4. `usuarioId` asigna el valor extraído de sesión y establece `0` como respaldo controlado.
5. `CreateOrderWithPromotionsAsync` ejecuta el siguiente paso solo después de validar.
6. Los argumentos transmiten identidad, datos normalizados, carrito y cancelación.
7. `Concat(...).ToList()` prepara la colección que se presentará; aquí forma parte de un flujo con efectos, por lo que el método completo sigue siendo imperativo.
8. La construcción de `OrderConfirmationViewModel` conserva tipo y dirección de entrega, y asigna el identificador, total y líneas autoritativas a un nuevo estado de confirmación.

#### Características evidenciadas

- Secuencia de instrucciones dependientes del orden.
- Asignación y actualización de propiedades del modelo.
- Condiciones y salidas tempranas.
- `foreach`, `continue` y acumulación en `RefreshCartItemsAsync`.
- Manejo de excepciones con rutas diferentes.
- Efectos secundarios: base de datos, correo, sesión y `TempData`.
- Transacción complementaria con `BEGIN TRANSACTION`, `INSERT`, `UPDATE`, `COMMIT` y `ROLLBACK` en SQL.

#### Por qué es adecuado

El checkout no es una sola transformación matemática: coordina validaciones y efectos que deben ocurrir en un orden predecible. El estilo imperativo hace explícitos los puntos en que el proceso continúa, se detiene o compensa un error.

La atomicidad del pedido e inventario queda en SQL Server. C# coordina el caso de uso; SQL protege la consistencia compartida. El procedimiento es evidencia complementaria, no el fragmento principal de este paradigma.

#### Relación con los otros paradigmas

- El flujo vive dentro de objetos como `CartController` y `StoreDbService`.
- Utiliza `StoreCheckoutPayloadBuilder.CreateItemsJson`, una transformación funcional acotada.
- Invoca un procedimiento SQL que contiene consultas declarativas y control transaccional.

#### Pruebas existentes

- `Proyecto_Final.Tests/Sprint4DomainTests.cs`
  - `CheckoutPayload_ContainsOnlyIdentifiersTypeAndQuantity`.
- `Proyecto_Final.Tests/OrderReceiptHtmlBuilderTests.cs`
  - `Receipt_UsesAuthoritativeTotalAfterDiscount`.
  - `Receipt_ShowsComboQuantityAndAuthoritativeTotal`.
  - `Receipt_ShowsGiftsAtZeroWithoutIncreasingTheTotal`.
  - `Receipt_MixedOrderKeepsSqlConfirmedTotalAndEscapesText`.
- `database/verify/0012_sprint4_functional_local.sql`
  - Checkout mixto, reintento idempotente, factura y cancelación/restauración dentro de una transacción con rollback.
- `database/verify/0012_concurrency_checkout_local.sql`
  - Ejecución paralela sobre inventario limitado.
- `database/verify/0012_idempotency_conflict_local.sql`
  - Conflicto cuando el mismo token recibe una carga diferente.
- `database/verify/0012_combo_inactive_component_local.sql`
  - Rechazo de un combo inválido sin alterar inventario.

#### Pruebas pendientes

- Usuario sin sesión y redirección al login.
- Carrito vacío.
- Cada campo obligatorio y método de pago inválido.
- `OperationToken` vacío.
- Fallo SMTP posterior a un pedido confirmado.
- Eliminación de `CartSessionKey` solamente después del éxito.
- Traducción de errores SQL de inventario a un mensaje público genérico.

#### Posibles preguntas del profesor

**Pregunta:** ¿Por qué el checkout es imperativo si contiene `Concat` y otras llamadas LINQ?

**Respuesta sugerida:** El paradigma se determina por el flujo principal. El método modifica estado, ejecuta efectos y depende del orden. Una transformación LINQ local no convierte todo el método en funcional.

**Pregunta:** ¿Dónde se garantiza que pedido e inventario se confirmen juntos?

**Respuesta sugerida:** `CartController` coordina, pero `sp_Store_CreateOrderWithPromotions` vuelve a validar y ejecuta los cambios dentro de una transacción SQL autoritativa.

**Pregunta:** ¿Por qué no se confía en el precio del carrito?

**Respuesta sugerida:** `CreateItemsJson` envía solo tipo, identificadores y cantidad. SQL vuelve a obtener precios, promociones y disponibilidad vigentes.

### 7.3. Paradigma funcional

#### Definición

La programación funcional modela la solución como composición de funciones y transformaciones de datos. Una función pura produce el mismo resultado para los mismos argumentos, no modifica estado externo y no altera sus entradas.

#### Problema que resuelve

La tendencia estacional puede recibir meses ausentes, duplicados o fuera del rango esperado. La interfaz necesita exactamente doce puntos ordenados, uno por mes, combinando los duplicados y completando los meses sin ventas con cero.

#### Módulo

Inteligencia y normalización de inventario.

#### Archivos y elementos involucrados

| Ruta | Elemento | Papel |
|---|---|---|
| `Proyecto_Final/Models/Admin/InventoryIntelligenceViewModels.cs` | `InventoryIntelligencePolicy.NormalizeTwelveMonths` | Evidencia funcional principal y usada por producción. |
| `Proyecto_Final/Models/Admin/InventoryIntelligenceViewModels.cs` | `CalculateSuggestedQuantity` | Cálculo puro complementario de cobertura y stock. |
| `Proyecto_Final/Services/InventoryIntelligenceDbService.cs` | `GetAsync` | Obtiene los datos y aplica `NormalizeTwelveMonths`. No es la evidencia funcional principal porque realiza acceso a datos. |
| `Proyecto_Final/Services/StoreCheckoutPayloadBuilder.cs` | `CreateItemsJson` | Proyección funcional complementaria de las líneas del carrito. |
| `Proyecto_Final/Views/InventoryIntelligence/Index.cshtml` | Vista de resultados | Consume la lista mensual normalizada y los indicadores. |

#### Entradas

Para `NormalizeTwelveMonths`:

- `IEnumerable<SeasonalTrendPoint>`.
- Cada punto aporta número de mes, total vendido y unidades vendidas.

Para `CalculateSuggestedQuantity`:

- Unidades vendidas.
- Meses recientes.
- Meses de cobertura.
- Stock de seguridad.
- Stock actual.

Para `CreateItemsJson`:

- Secuencia de `CartItemViewModel`.

#### Proceso

1. Filtrar meses fuera de 1 a 12.
2. Agrupar puntos por número de mes.
3. Sumar ventas y unidades de cada grupo.
4. Convertir los grupos a un diccionario.
5. Generar el rango 1 a 12.
6. Proyectar el valor agrupado o un punto vacío por cada mes.
7. Materializar una nueva lista.

#### Salidas

- Lista nueva de exactamente doce `SeasonalTrendPoint`.
- Meses en orden ascendente.
- Duplicados consolidados.
- Meses ausentes representados con cero.

#### Fragmento real

Ruta: `Proyecto_Final/Models/Admin/InventoryIntelligenceViewModels.cs`, líneas aproximadas 107-128.

```csharp
var byMonth = source
    .Where(point => point.NumeroMes is >= 1 and <= 12)
    .GroupBy(point => point.NumeroMes)
    .ToDictionary(
        group => group.Key,
        group => new SeasonalTrendPoint
        {
            NumeroMes = group.Key,
            NombreMes = MonthNames[group.Key - 1],
            TotalVendido = group.Sum(point => point.TotalVendido),
            UnidadesVendidas = group.Sum(point => point.UnidadesVendidas)
        });

return Enumerable.Range(1, 12)
    .Select(month => byMonth.GetValueOrDefault(month) ?? new SeasonalTrendPoint
    {
        NumeroMes = month,
        NombreMes = MonthNames[month - 1]
    })
    .ToList();
```

#### Explicación línea por línea

1. `source` es la secuencia de entrada; no se modifica.
2. `Where` conserva únicamente los meses válidos.
3. `GroupBy` agrupa todos los puntos que representan el mismo mes.
4. `ToDictionary` transforma cada grupo en una entrada identificada por mes.
5. El inicializador crea un nuevo `SeasonalTrendPoint` para el grupo.
6. `Sum` combina totales y unidades sin usar acumuladores externos.
7. `Enumerable.Range(1, 12)` declara la serie completa esperada.
8. `Select` transforma cada número en el punto agregado o en uno nuevo con cero implícito.
9. `ToList` materializa la salida como una colección nueva.

#### Características evidenciadas

- Función estática sin base de datos, sesión, archivos ni correo.
- Resultado determinado por el argumento de entrada.
- Transformaciones encadenadas.
- Lambdas para filtrado, clave, suma y proyección.
- Ausencia de mutación de la colección recibida.
- Creación de nuevos objetos para la salida.

#### Por qué es adecuado

La normalización es una transformación de datos autocontenida. Separarla del servicio de acceso a datos permite razonar sobre el resultado y probarlo con colecciones pequeñas sin preparar SQL Server.

No hace falta crear un servicio funcional adicional: `InventoryIntelligencePolicy` ya contiene la evidencia necesaria. Su ubicación actual dentro del archivo de ViewModels reduce visibilidad arquitectónica, pero no cambia la pureza de `NormalizeTwelveMonths`.

#### Evidencias complementarias y límites

`CalculateSuggestedQuantity` es determinista y no tiene efectos secundarios. Sin embargo, actualmente solo está referenciada por pruebas; la fórmula autoritativa del reporte de compra se calcula en SQL. Debe presentarse como complemento, no como evidencia única de una función usada por el flujo real.

`StoreCheckoutPayloadBuilder.CreateItemsJson` proyecta cada línea a tipo, identificadores y cantidad mediante `Select`, y devuelve el JSON serializado. Es una transformación determinista para una entrada estable.

`PromotionEngine.Apply` no debe presentarse como función pura. Aunque usa `Where` y `OrderBy`, modifica los objetos de `items` y utiliza `DateTime.UtcNow` cuando no se proporciona `evaluationDate`.

#### Relación con los otros paradigmas

- `InventoryIntelligenceDbService`, un objeto, obtiene datos y luego delega la normalización pura.
- `GetAsync` sigue un flujo imperativo para abrir la conexión y cargar tres conjuntos de datos.
- Los datos originales provienen de procedimientos SQL declarativos, pero la evidencia funcional se encuentra en la transformación C# en memoria.

#### Pruebas existentes

- `Proyecto_Final.Tests/Sprint4DomainTests.cs`
  - `PurchaseSuggestion_UsesDemandCoverageAndSafetyStock`.
  - `SeasonalTrend_AlwaysReturnsTwelveUniqueOrderedMonths`.
  - `CheckoutPayload_ContainsOnlyIdentifiersTypeAndQuantity`.

`SeasonalTrend_AlwaysReturnsTwelveUniqueOrderedMonths` comprueba doce meses únicos y ordenados, consolidación de dos puntos para febrero y conservación de unidades.

#### Pruebas pendientes

- Confirmar que la colección y sus objetos de entrada no cambian.
- Ejecutar la función con los mismos datos en diferente orden y comparar resultados.
- Confirmar que meses 0, 13 y negativos se ignoran.
- Definir y probar el comportamiento ante `source == null`.
- Probar valores negativos y overflow de `CalculateSuggestedQuantity`.
- Confirmar determinismo mediante dos invocaciones equivalentes.

#### Posibles preguntas del profesor

**Pregunta:** ¿Todo uso de LINQ es programación funcional?

**Respuesta sugerida:** No. LINQ facilita transformaciones funcionales, pero hay que comprobar ausencia de efectos secundarios y dependencia exclusiva de los argumentos. `NormalizeTwelveMonths` cumple; `PromotionEngine.Apply` no.

**Pregunta:** ¿Por qué la lista de salida puede ser mutable si la función es pura?

**Respuesta sugerida:** La pureza describe la evaluación: la función no modifica la entrada ni estado externo y crea una lista nueva. Retornar una interfaz inmutable podría reforzar el contrato, pero no invalida el comportamiento puro observado durante la llamada.

**Pregunta:** ¿Por qué `InventoryIntelligenceDbService.GetAsync` no es la evidencia funcional?

**Respuesta sugerida:** Porque abre una conexión y modifica el modelo mientras lee resultados. La función pura está separada en `NormalizeTwelveMonths` y se invoca después de cargar los datos.

### 7.4. Paradigma declarativo

#### Definición

La programación declarativa expresa qué resultado se desea mediante relaciones, filtros, agrupaciones y restricciones, sin describir el algoritmo físico de bajo nivel que debe recorrer, unir u ordenar los datos.

#### Problema que resuelve

El reporte financiero debe combinar presupuestos aprobados y gastos, excluir anulados, separar pendientes de gasto real, calcular porcentajes, producir agrupaciones por departamento y categoría, completar doce meses y paginar el detalle.

#### Módulo

Reporte financiero de presupuesto contra gasto real.

#### Archivos y elementos involucrados

| Ruta | Elemento | Responsabilidad |
|---|---|---|
| `database/migrations/0010_operating_expenses_alignment.sql` | `vw_OperatingExpenseImpact` | Declara la relación entre gasto, departamento, categoría, presupuesto e impacto acumulado. |
| `database/migrations/0011_budget_actual_comparison.sql` | `sp_BudgetComparison_Dashboard` | Declara filtros, resumen, agrupaciones, serie mensual y detalle paginado. |
| `Proyecto_Final/Services/BudgetComparisonDbService.cs` | `GetDashboardAsync` | Ejecuta el procedimiento y convierte sus conjuntos de resultados en ViewModels. Es consumidor, no evidencia declarativa principal. |
| `Proyecto_Final/Controllers/BudgetComparisonController.cs` | `BudgetComparisonController` | Expone `Index`, `Print` y `ExportCsv`. |
| `Proyecto_Final/Views/BudgetComparison/Index.cshtml` | Vista tipada | Presenta filtros, resumen, agrupaciones, serie y drill-down. |
| `Proyecto_Final/Views/BudgetComparison/Print.cshtml` | Vista tipada | Presenta la versión imprimible del reporte. |

#### Entradas

Parámetros de `sp_BudgetComparison_Dashboard`:

- `@Anio`.
- `@DepartamentoId` opcional.
- `@Mes` opcional.
- `@CategoriaId` opcional.
- `@EstadoGasto` opcional.
- `@Pagina` y `@TamanoPagina`.
- `@FechaNegocio`.

#### Proceso

1. Seleccionar el presupuesto aprobado que coincide con los filtros.
2. Seleccionar gastos no anulados desde `vw_OperatingExpenseImpact`.
3. Agregar registrado, aprobado y pagado.
4. Calcular real, disponible, variación, porcentaje y proyección.
5. Producir agrupaciones por departamento y categoría.
6. Crear una serie de doce meses mediante una CTE.
7. Ordenar y paginar el detalle.
8. Devolver opciones de departamentos y categorías.

#### Salidas

El procedimiento devuelve varios conjuntos de resultados:

- Resumen financiero.
- Filas por departamento.
- Filas por categoría.
- Serie mensual de doce meses.
- Detalle paginado de gastos.
- Departamentos disponibles.
- Categorías disponibles.

`BudgetComparisonDbService.GetDashboardAsync` los materializa en `BudgetComparisonDashboardViewModel`.

#### Fragmento real

Ruta: `database/migrations/0011_budget_actual_comparison.sql`, líneas aproximadas 13-16.

```sql
SELECT p.DepartamentoId,pd.CategoriaId,pd.Mes,pd.MontoAsignado INTO #B
FROM dbo.PresupuestosAnuales p INNER JOIN dbo.PresupuestoDetalles pd ON pd.PresupuestoId=p.PresupuestoId
WHERE p.Anio=@Anio AND p.Estado=N'Aprobado' AND p.Activo=1 AND(@DepartamentoId IS NULL OR p.DepartamentoId=@DepartamentoId)AND(@Mes IS NULL OR pd.Mes=@Mes)AND(@CategoriaId IS NULL OR pd.CategoriaId=@CategoriaId);
SELECT * INTO #E FROM dbo.vw_OperatingExpenseImpact WHERE YEAR(FechaGasto)=@Anio AND Estado<>N'Anulado' AND(@DepartamentoId IS NULL OR DepartamentoId=@DepartamentoId)AND(@Mes IS NULL OR MONTH(FechaGasto)=@Mes)AND(@CategoriaId IS NULL OR CategoriaId=@CategoriaId)AND(@EstadoGasto IS NULL OR Estado=@EstadoGasto);
```

#### Explicación línea por línea

1. El primer `SELECT` declara las columnas de presupuesto necesarias y deposita el conjunto filtrado en `#B`.
2. `FROM ... INNER JOIN` declara la relación entre cabecera anual y detalle mensual mediante `PresupuestoId`.
3. `WHERE` declara las condiciones: año, estado aprobado, registro activo y filtros opcionales.
4. El segundo `SELECT` obtiene el conjunto de gastos desde la vista declarativa y excluye `Anulado`.
5. Las expresiones `@Parametro IS NULL OR ...` hacen opcionales los filtros sin programar un recorrido manual de las filas.

El optimizador de SQL Server decide índices, tipo de unión, orden de acceso y otras operaciones físicas. El procedimiento declara el conjunto esperado.

#### Características evidenciadas

- Selección y proyección con `SELECT`.
- Relaciones con `INNER JOIN`.
- Filtros mediante `WHERE`.
- Agregaciones con `SUM` y `COUNT`.
- Expresiones condicionales `CASE` dentro de la consulta.
- Subconsultas correlacionadas mediante `OUTER APPLY`.
- CTE para declarar los doce meses.
- Ordenamiento y paginación declarativos.
- Vista reutilizable como relación derivada.

#### Por qué es adecuado

El reporte se basa en conjuntos de datos relacionados y agregados. SQL permite expresar el resultado cerca de los datos, mantener filtros y sumas consistentes y delegar la estrategia física al motor.

ADO.NET no es la evidencia declarativa principal. `BudgetComparisonDbService.GetDashboardAsync` ejecuta instrucciones imperativas para abrir la conexión y leer resultados; su importancia académica es mostrar cómo la aplicación integra y consume el resultado declarado en SQL.

#### Relación con los otros paradigmas

- `BudgetComparisonController` y `BudgetComparisonDbService` son objetos que encapsulan la interacción.
- `GetDashboardAsync` lee los result sets mediante un flujo imperativo.
- Funciones C# como cálculos o sanitización pueden complementar la presentación, pero no sustituyen la consulta declarativa.

#### Pruebas existentes

- La sintaxis de las migraciones forma parte de la validación con ScriptDom documentada por el proyecto.
- `Proyecto_Final.Tests/Sprint4DomainTests.cs`
  - `Projection_IsDeterministicAndNotAiBased` prueba fórmulas C# relacionadas, pero no el procedimiento SQL.
  - `CsvExport_NeutralizesSpreadsheetFormulaInjection` prueba la salida CSV, no la consulta.
- `Proyecto_Final.Tests/Sprint4ControllerSecurityTests.cs`
  - Incluye `BudgetComparisonController` dentro de la verificación de autorización.
- `docs/qa-final.md` contiene el recorrido manual pendiente para comparación anual/mensual, departamento, categoría, proyección, CSV e impresión.

No existe actualmente en `database/verify/` una prueba específica de resultados para la migración 0011. La validación sintáctica no equivale a ejecutar el reporte.

#### Pruebas pendientes

- Presupuesto y gasto real con filtros vacíos.
- Exclusión de gastos anulados.
- Separación de registrados como pendientes y aprobados/pagados como real.
- Departamento sin presupuesto.
- Categoría por encima del presupuesto.
- Serie de exactamente doce meses, incluidos meses sin movimientos.
- Año futuro con proyección cero y año vigente con meses transcurridos.
- Paginación y orden estable por fecha e identificador.
- Correspondencia de columnas y result sets con `BudgetComparisonDbService`.

#### Posibles preguntas del profesor

**Pregunta:** ¿Un procedimiento almacenado siempre es declarativo?

**Respuesta sugerida:** No necesariamente. T-SQL también permite control imperativo. En esta evidencia se seleccionan específicamente las consultas `SELECT`, relaciones, filtros, agregaciones, CTE y ordenamiento que declaran conjuntos de resultados.

**Pregunta:** ¿Por qué `BudgetComparisonDbService` aparece si ADO.NET no es declarativo?

**Respuesta sugerida:** Para demostrar integración. La evidencia declarativa está en la vista y el procedimiento; el servicio consume sus result sets y los entrega al MVC.

**Pregunta:** ¿Quién decide cómo ejecutar el `JOIN`?

**Respuesta sugerida:** El optimizador de SQL Server. La consulta declara la relación y el resultado, mientras el motor selecciona el plan físico.

## 8. Diferencias entre los cuatro paradigmas

| Aspecto | Orientado a objetos | Imperativo | Funcional | Declarativo |
|---|---|---|---|---|
| Pregunta principal | ¿Qué objetos colaboran y qué responsabilidad tiene cada uno? | ¿Qué pasos deben ejecutarse y en qué orden? | ¿Cómo transformar entradas en salidas sin efectos secundarios? | ¿Qué conjunto o resultado se desea obtener? |
| Unidad destacada | Clase, interfaz y objeto | Instrucción y estado | Función y expresión | Consulta, relación o regla |
| Estado | Encapsulado dentro de objetos | Se consulta y modifica explícitamente | Se evita la mutación observable | El motor administra la evaluación del conjunto |
| Control | Métodos y colaboración | `if`, ciclos, retornos, excepciones | Composición, proyección, filtrado y reducción | `SELECT`, `WHERE`, `JOIN`, agregaciones y restricciones |
| Evidencia elegida | `IComboDbService` y colaboradores | `CartController.Checkout` | `NormalizeTwelveMonths` | `vw_OperatingExpenseImpact` y `sp_BudgetComparison_Dashboard` |
| Riesgo de confusión | Creer que toda clase demuestra buen diseño OOP | Ignorar que un método puede contener expresiones funcionales | Creer que toda lambda o LINQ es pura | Confundir el código ADO.NET consumidor con la consulta SQL |

## 9. Evidencia de integración dentro de una misma solución

Los paradigmas no se ejecutan como aplicaciones independientes. Se integran dentro de los mismos casos de uso:

1. ASP.NET Core construye objetos y resuelve interfaces mediante inyección de dependencias.
2. Los controladores ejecutan flujos imperativos para validar y coordinar solicitudes.
3. Los servicios pueden delegar transformaciones acotadas a funciones puras.
4. Los servicios ADO.NET invocan consultas y procedimientos declarativos de SQL Server.
5. Los resultados regresan como ViewModels a vistas Razor fuertemente tipadas.

Ejemplo de integración en inteligencia de inventario:

- `InventoryIntelligenceController` recibe el filtro como objeto.
- `InventoryIntelligenceDbService.GetAsync` carga los resultados en orden imperativo.
- SQL declara los datos agregados de inventario y ventas.
- `InventoryIntelligencePolicy.NormalizeTwelveMonths` transforma el resultado en memoria sin modificar la entrada.
- `Views/InventoryIntelligence/Index.cshtml` presenta el ViewModel.

Ejemplo de integración en checkout:

- `CartController` y `StoreDbService` son objetos construidos por DI.
- `Checkout` coordina imperativamente el caso de uso.
- `StoreCheckoutPayloadBuilder.CreateItemsJson` proyecta las líneas mediante una función acotada.
- `sp_Store_CreateOrderWithPromotions` usa consultas declarativas y una transacción para confirmar pedido e inventario.

## 10. Pruebas existentes

### Orientado a objetos

- Reglas de composición y disponibilidad de combos en `Sprint4DomainTests`.
- Permisos y antiforgery de `CombosController` en `Sprint4ControllerSecurityTests`.
- Vistas fuertemente tipadas verificables por compilación del proyecto MVC.

### Imperativo

- Contrato mínimo del payload de checkout.
- Construcción del comprobante con total autoritativo.
- Pruebas LocalDB de checkout mixto, reintento, idempotencia, inventario y concurrencia.

### Funcional

- Cálculo de sugerencia de compra.
- Normalización a doce meses únicos y ordenados.
- Proyección del payload sin precio, stock ni nombre manipulable.

### Declarativo

- Validación sintáctica general con ScriptDom documentada en el repositorio.
- Pruebas C# de proyección y sanitización relacionadas con el reporte.
- Matriz de QA manual para resumen, filtros, CSV e impresión.

La documentación activa registra 117 pruebas .NET aprobadas al cierre local de la integración del 28 de julio de 2026. Ese dato es evidencia histórica de esa ejecución y no sustituye una ejecución actual. En este bloque documental no se ejecutaron pruebas, aplicación ni SQL.

## 11. Pruebas pendientes

Prioridad académica recomendada:

1. Probar `NormalizeTwelveMonths` respecto a no mutación, orden de entrada y meses inválidos.
2. Caracterizar el POST de `CartController.Checkout` en sus rutas principales y negativas.
3. Probar la colaboración de `CombosController` con un doble de `IComboDbService`.
4. Crear, solo en un bloque posterior autorizado, una verificación aislada de resultados de `sp_BudgetComparison_Dashboard` sobre SQL Server desechable.
5. Ejecutar QA autenticado del reporte y checkout en un entorno autorizado.

Las migraciones aplicadas no deben modificarse para añadir estas pruebas. Cualquier verificación SQL futura debe ser un archivo separado, de alcance LocalDB y con datos que se reviertan.

## 12. Riesgos para la defensa

- Presentar `PromotionEngine.Apply` como función pura a pesar de que modifica `items` y puede leer el reloj.
- Presentar cualquier uso de LINQ como prueba automática del paradigma funcional.
- Presentar ADO.NET o `BudgetComparisonDbService` como evidencia declarativa principal.
- Afirmar que los procedimientos SQL son orientación a objetos.
- Usar `CalculateSuggestedQuantity` como única evidencia funcional sin aclarar que actualmente solo la referencian las pruebas.
- No explicar que el checkout se divide entre coordinación C# y autoridad transaccional SQL.
- Confundir validación sintáctica de SQL con prueba de resultados.
- Editar o reformatear migraciones ya aplicadas para preparar diapositivas.
- Presentar las 117 pruebas históricas como si hubieran sido ejecutadas durante este bloque.
- Depender de una demostración en Azure de la migración 0012, que continúa pendiente de aplicación en Azure DEV según la documentación activa.
- Mostrar fragmentos demasiado largos y perder el punto conceptual de cada paradigma.

## 13. Guion resumido para demostrar cada paradigma

### Orientado a objetos: 2-3 minutos

1. Abrir `Proyecto_Final/Services/ComboDbService.cs`.
2. Mostrar `IComboDbService` y `ComboDbService : IComboDbService`.
3. Abrir `CombosController` y señalar la dependencia por interfaz.
4. Mostrar el registro en `Program.cs`.
5. Mostrar `ComboFormViewModel` y una vista con `@model`.
6. Cerrar con la idea: contrato, implementación, composición y responsabilidades separadas.

### Imperativo: 3 minutos

1. Abrir el POST `CartController.Checkout`.
2. Recorrer en orden reconstrucción, normalización, condiciones y `ModelState`.
3. Mostrar la llamada a `CreateOrderWithPromotionsAsync`.
4. Mostrar creación de confirmación, limpieza de sesión y manejo de excepciones.
5. Mencionar el procedimiento SQL únicamente para explicar atomicidad e inventario.
6. Cerrar con la idea: el orden y los cambios de estado son esenciales.

### Funcional: 2-3 minutos

1. Abrir `InventoryIntelligencePolicy.NormalizeTwelveMonths`.
2. Identificar entrada y salida.
3. Explicar `Where`, `GroupBy`, `Sum`, `Range` y `Select`.
4. Señalar que se crean un diccionario y una lista nuevos.
5. Mostrar la prueba de doce meses.
6. Contrastar brevemente con `PromotionEngine.Apply`: usa LINQ, pero no es pura.

### Declarativo: 3 minutos

1. Abrir `vw_OperatingExpenseImpact` y explicar la relación declarada.
2. Abrir `sp_BudgetComparison_Dashboard` y mostrar filtros y agregaciones.
3. Mostrar la CTE de meses y la paginación.
4. Explicar que SQL Server decide el plan físico.
5. Abrir `BudgetComparisonDbService.GetDashboardAsync` solo para mostrar el consumo de result sets.
6. Mostrar las vistas `Index` y `Print` como salida integrada.

## 14. Conclusión

DistribuidoraJJ ya contiene evidencia suficiente de los cuatro paradigmas solicitados sin requerir cambios en el código de producción ni en SQL.

- La administración y venta de combos demuestra orientación a objetos mediante contratos, implementaciones, inyección, modelos y vistas tipadas.
- El checkout demuestra programación imperativa mediante un flujo ordenado de validaciones, asignaciones, efectos y manejo de errores.
- La normalización de inteligencia de inventario demuestra programación funcional mediante una transformación pura y compuesta de datos en memoria.
- El reporte de presupuesto contra gasto real demuestra programación declarativa mediante vistas y consultas SQL que describen relaciones, filtros y agregaciones.

La adaptación académica debe concentrarse en presentar estas evidencias con precisión y fortalecer las pruebas pendientes, sin refactorizar los módulos estables ni modificar migraciones aplicadas.
