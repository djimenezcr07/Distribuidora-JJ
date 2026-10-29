# Paradigmas de programación aplicados

La consigna académica de `docs/paradigmas-sc250.md` define exactamente cuatro paradigmas: **orientado a objetos, imperativo, funcional y declarativo**. No se sustituye “imperativo” por “dirigido por eventos”. El documento SC-250 conserva la defensa extensa; esta página es el mapa canónico del código vigente.

| Paradigma | Definición breve | Ubicación y elementos reales | Historias | Por qué es real | Cómo probarlo |
|---|---|---|---|---|---|
| Orientado a objetos | El sistema se compone de objetos con responsabilidades y contratos explícitos. | `IPurchasingService`, `IEmployeesService`, `IAttendanceService`, `IPayrollService`, `IPaySlipService`, `IPaySlipEmailSender` e `IProductImageStorageService`, con implementaciones registradas en `Program.cs`. | CU-101–104, CU-111–114, CU-262 | Los controladores dependen de contratos y la entrega SMTP puede sustituirse por un fake sin alterar la lógica de planilla. | Compilar la solución y ejecutar `PurchasingTests`, `HrSecurityAndRulesTests` y `PaySlipSecurityAndDeliveryTests`. |
| Imperativo | Un flujo ordena instrucciones y efectos de estado paso a paso. | `PurchaseOrdersController.Receive`, `PaySlipDeliveryCoordinator.SendAsync` e `InventoryController.Edit`: preparar, ejecutar el efecto, registrar resultado y limpiar recursos. | CU-102, CU-114, CU-053/055 | El orden evita duplicar inventario/correos y evita huérfanos: el resultado SMTP se registra después del intento y una imagen anterior solo se elimina después del commit de datos. | Ejecutar el harness 0013–0016, las pruebas de boletas y las pruebas del ciclo de imágenes. |
| Funcional | Funciones deterministas transforman entradas sin depender de estado externo ni mutarlas. | `PurchasingPolicy`, `ReportMetrics`, `CrossSellPolicy`, `AttendanceRules` y `PayrollCalculationPolicy`; esta última produce líneas, totales, snapshot y huella SHA-256. | CU-102, CU-104, CU-112, CU-113, CU-132/134, CU-262 | Las mismas entradas producen la misma salida; las tasas llegan como datos versionados, no como constantes legales ocultas. | Ejecutar `PayrollRulesAndSecurityTests` dos veces y comparar totales, snapshot y huella; validar configuración faltante y deducciones inválidas. |
| Declarativo | Se describe el resultado o la regla deseada y el motor decide cómo obtenerla. | DataAnnotations y LINQ; constraints, permisos, vigencias, `OPENJSON` y transiciones declaradas en 0015–0020. | CU-111–114, CU-132, CU-134, CU-262 | Los modelos expresan rangos y formatos; SQL expresa invariantes, pertenencia, segregación e idempotencia sin depender de texto de interfaz. | Ejecutar ScriptDom, el harness 0013–0016 y los verificadores de 0017–0020 cuando exista una base autorizada. |

## Demostración mínima

1. Mostrar que los controladores reciben interfaces y que las transacciones viven en servicios/procedimientos.
2. Ejecutar las pruebas puras de `PurchasingPolicy`, `ReportMetrics`, `CrossSellPolicy`, `AttendanceRules` y `PayrollCalculationPolicy` dos veces y comparar resultados.
3. Abrir 0015/0019 y cambiar únicamente parámetros/datos de reglas para demostrar comportamiento declarativo sin modificar el algoritmo.
4. Ejecutar el flujo de recepción y el fake SMTP para observar la secuencia imperativa y confirmar que un reintento no duplica inventario ni correo.

La evidencia extensa, fragmentos comentados y guion académico permanecen en `docs/paradigmas-sc250.md`; ambos documentos usan la misma lista y no presentan paradigmas contradictorios.
