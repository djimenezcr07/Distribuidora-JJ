# Distribuidora JJ

Sistema web empresarial para comercio electrónico y gestión operativa de una distribuidora. Integra inventario, pedidos, facturación, clientes, empleados y herramientas administrativas.

## Tecnologías

- C# y .NET 9
- ASP.NET Core MVC y API REST
- SQL Server mediante ADO.NET / Microsoft.Data.SqlClient
- HTML, CSS, JavaScript y Bootstrap
- Pruebas automatizadas con xUnit

## Estructura

| Carpeta | Contenido |
| --- | --- |
| `Proyecto_Final/` | Aplicación web MVC |
| `Proyecto_FinalAPI/` | API REST |
| `Proyecto_Final.Tests/` | Pruebas automatizadas |
| `database/` | Scripts SQL y migraciones |
| `database_Esteban/` | Scripts SQL históricos |
| `docs/` | Documentación funcional y técnica |
| `scripts/` | Herramientas de validación |
| `tools/SqlSyntaxValidator/` | Validador de sintaxis SQL |

## Desarrollo local

Requisitos: SDK de .NET 9 y una instancia de SQL Server configurada para desarrollo.

```bash
dotnet restore Proyecto_Final.slnx
dotnet build Proyecto_Final.slnx --configuration Release
dotnet test Proyecto_Final.slnx --configuration Release
```

Las conexiones y demás valores privados se configuran fuera del repositorio mediante variables de entorno o User Secrets. Consulta `docs/credenciales-configuracion-segura.md`. Revisa la documentación de base de datos antes de ejecutar scripts; los baselines y scripts históricos no deben ejecutarse indiscriminadamente sobre una base existente.

## Estado de esta publicación

Esta versión corresponde a una copia del proyecto local preparada el 28 de octubre de 2026. Se publica como trabajo en evolución; los ajustes posteriores se incorporarán en nuevos commits.

Validación realizada sobre esta copia:

- Compilación Release correcta, sin advertencias ni errores.
- Revisión automatizada de secretos correcta: 1.019 archivos revisados antes de añadir este README.
- Sintaxis SQL correcta: 158 archivos, 1.060 lotes y cero errores.
- Pruebas: 725 superadas y 3 fallidas de 728.

Pruebas pendientes de ajuste:

1. `Stage2DesignSystemTests.Stage2Css_UsesPrefixedTokensAndIntroducesNoImportantOverrides`: la lista esperada de CSS no incluye `chat-v2.css`.
2. `OrderWorkflowPresentationTests.ApprovalConfirmation_UsesExistingTempDataWithoutExecutingApproval`: diferencia entre los estados esperados `Liberado` y `Facturado`.
3. `Sprint4ControllerSecurityTests.Sprint4Controllers_RequirePermissionAuthorization`: expectativa de autorización pendiente de revisión en `DocumentsController`.

No se incluyen secretos, perfiles de publicación, datos cargados por usuarios, archivos de compilación ni el historial Git del repositorio educativo.

## Autor

[Danny Jiménez Palma](https://github.com/djimenezcr07) · [LinkedIn](https://www.linkedin.com/in/danny-jim%C3%A9nez-palma-089646312/)
