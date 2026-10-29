# Sprint 4 de Danny: CU-201, CU-202, CU-221, CU-222 y CU-223

## Estado verificable

Las cinco historias están implementadas en una rama apilada sobre el PR #112. Build, pruebas automatizadas y sintaxis SQL pasan. Las migraciones 0007–0011 aparecen aplicadas en Azure DEV y sus objetos, columnas principales, índices, constraints y permisos fueron verificados independientemente el 23 de julio de 2026. Falta completar el login con una contraseña de prueba autorizada y ejecutar el QA funcional autenticado; los issues permanecen abiertos.

## Arquitectura entregada

- CU-201: `DocumentsController`, `DocumentManagementDbService` y `PrivateFileStorageService`; metadatos, filtros, paginación, versiones, SHA-256, descarga autorizada, auditoría y borrado lógico.
- CU-202: `DocumentAlertService`; fecha de negocio `America/Costa_Rica`, umbrales configurables 30/15/7/1/0, clave SQL idempotente, centro interno, atención y SMTP opcional/no bloqueante.
- CU-221: `BudgetsController` y `BudgetDbService`; presupuesto anual normalizado por departamento/categoría/mes, distribución decimal, estados, auditoría y segregación creador/aprobador.
- CU-222: evolución del `ExpensesController`/`ExpensesDbService` existente; token idempotente, total calculado por servidor, comprobante privado, transiciones, impacto y permiso de override.
- CU-223: `BudgetComparisonController` y `BudgetComparisonDbService`; resumen SQL, niveles, pendientes separados, anulados excluidos, proyección determinista, drill-down, impresión y CSV seguro.

## Orden de despliegue

1. Revisar y aprobar el PR apilado y confirmar que PR #112 sigue como base.
2. Crear y verificar BACPAC de la base objetivo.
3. No volver a ejecutar 0007–0011 en Azure DEV. Revisar la evidencia existente del ejecutor y confirmar backup/rollback.
4. Verificar por separado las dependencias 0002–0006; no registrarlas como aplicadas sin objetos reales.
5. Configurar `PrivateStorage__RootPath` fuera de `wwwroot`, con persistencia y backup.
6. Mantener correo deshabilitado hasta validar SMTP; la alerta interna funciona sin correo.
7. Ejecutar el bloque Sprint 4 de `docs/qa-final.md`; adjuntar evidencia a los issues #74, #75, #79, #80 y #81.

## Rollback y recuperación

- No borrar datos financieros/documentales como rollback ordinario. Retirar rutas/servicios y procedimientos mediante una migración compensatoria.
- Antes de revertir archivos, conservar `PrivateStorage` y su correspondencia con `StorageKey`; no restaurar una base sin restaurar el mismo snapshot de archivos.
- Si 0010 encuentra `GastosOperativos` legado, conserva las filas y las marca con datos de compatibilidad; no inventa departamento/categoría ni ejecuta el script histórico de Esteban.
- Restaurar BACPAC es el último recurso y requiere aprobación expresa.

## Decisiones y límites

- El comprobante de gasto se conserva durante la edición; CU-222 no requiere versionado de comprobantes. Las versiones completas corresponden a CU-201.
- La proyección no usa IA: `real acumulado / meses transcurridos * 12`.
- Las gráficas son barras CSS renderizadas por servidor; no se agregó una dependencia JavaScript externa.
- La tabla mensual `CuentasPresupuestarias` queda como consulta legada temporal, protegida por `GASTOS_LEGADO_VER`; el modelo autoritativo nuevo es anual.
