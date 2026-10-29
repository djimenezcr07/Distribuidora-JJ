# Rollback de 0015 — reportes comerciales

Los permisos y procedimientos son aditivos. Para retirar la funcionalidad, desplegar primero una versión de la aplicación que no invoque `dbo.sp_Reportes_VentasDetallado` ni `dbo.sp_Reportes_DesempenoVendedores`.

Después, mediante una migración compensatoria trazable:

1. marcar inactivos `REPORTES_VENTAS_VER` y `REPORTES_VENDEDORES_VER`;
2. eliminar sus asignaciones únicamente tras confirmar que no existen integraciones dependientes;
3. retirar los procedimientos;
4. registrar la compensación en `SchemaMigrationHistory`.

No se recomienda borrar el registro `0015_sales_and_seller_reports` ni modificar manualmente una base compartida.
