# Cobertura automatizada

Fecha de ejecución: 2026-08-04. Comando reproducible:

```powershell
dotnet test .\Proyecto_Final.Tests\Proyecto_Final.Tests.csproj --configuration Release --collect:"XPlat Code Coverage" --results-directory .\TestResults\coverage
```

Resultado global de Cobertura:

| Métrica | Cubierto | Total | Porcentaje |
|---|---:|---:|---:|
| Líneas | 895 | 15.407 | 5,80% |
| Ramas | 417 | 10.631 | 3,92% |

El porcentaje global es bajo. Se conserva como línea base real y no se usa para declarar el repositorio terminado. La suite aprobó 189/189 pruebas.

Cobertura de reglas críticas incorporadas durante Puerta A:

| Componente | Líneas | Ramas |
|---|---:|---:|
| `AttendanceRules` | 100,0% | 100,0% |
| `PayrollCalculationPolicy` | 92,3% | 77,5% |
| `PaySlipDeliveryCoordinator` | 100,0% | 100,0% |
| `PaySlipHtmlBuilder` | 100,0% | 100,0% |
| `ProductImageStorageService` | 87,8% | 62,5% |

El XML se genera en `TestResults/coverage/<id>/coverage.cobertura.xml` y no se versiona porque es un artefacto de ejecución. Los siguientes incrementos deben priorizar controladores y servicios de acceso a datos históricos, que concentran la brecha.
