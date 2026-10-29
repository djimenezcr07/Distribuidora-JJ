SET NOCOUNT ON;
IF NOT EXISTS(SELECT 1 FROM dbo.SchemaMigrationHistory WHERE MigrationId=N'0017_rrhh_employee_records' AND Status=N'Applied' AND LEN(FileSha256)=64) THROW 55020,N'0017 no figura aplicada.',1;
IF COL_LENGTH(N'dbo.Empleados',N'VersionFila') IS NULL THROW 55021,N'Falta control de concurrencia en Empleados.',1;
IF OBJECT_ID(N'dbo.EmpleadoHistorialSalarios',N'U') IS NULL OR OBJECT_ID(N'dbo.RRHHAuditoria',N'U') IS NULL THROW 55022,N'Faltan tablas RRHH.',1;
IF OBJECT_ID(N'dbo.sp_RRHH_UpdateEmployee',N'P') IS NULL THROW 55023,N'Falta procedimiento de actualización segura.',1;
IF EXISTS(SELECT required.Codigo FROM(VALUES(N'EMPLEADOS_VER'),(N'EMPLEADOS_CREAR'),(N'EMPLEADOS_EDITAR'),(N'EMPLEADOS_TAREAS'),(N'EMPLEADOS_SOLICITUDES'))required(Codigo)
          WHERE NOT EXISTS(SELECT 1 FROM dbo.Permisos p WHERE p.Codigo=required.Codigo AND p.Activo=1)) THROW 55024,N'Faltan permisos RRHH.',1;
SELECT MigrationId,FileSha256,Status,AppliedAtUtc FROM dbo.SchemaMigrationHistory WHERE MigrationId=N'0017_rrhh_employee_records';
