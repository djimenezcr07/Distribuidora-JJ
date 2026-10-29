SET NOCOUNT ON;
IF NOT EXISTS(SELECT 1 FROM dbo.SchemaMigrationHistory WHERE MigrationId=N'0018_rrhh_attendance' AND Status=N'Applied' AND LEN(FileSha256)=64) THROW 55130,N'0018 no figura aplicada.',1;
IF OBJECT_ID(N'dbo.EmpleadoJornadas',N'U') IS NULL THROW 55131,N'Falta EmpleadoJornadas.',1;
IF EXISTS(SELECT 1 FROM dbo.EmpleadoJornadas WHERE HorasOrdinarias+HorasExtra+HorasAusencia<=0 OR HorasOrdinarias+HorasExtra+HorasAusencia>24) THROW 55132,N'Existen jornadas inválidas.',1;
IF EXISTS(SELECT required.Codigo FROM(VALUES(N'RRHH_JORNADAS_VER_PROPIAS'),(N'RRHH_JORNADAS_REGISTRAR'),(N'RRHH_JORNADAS_APROBAR'))required(Codigo) WHERE NOT EXISTS(SELECT 1 FROM dbo.Permisos p WHERE p.Codigo=required.Codigo AND p.Activo=1)) THROW 55133,N'Faltan permisos de jornadas.',1;
IF OBJECT_ID(N'dbo.sp_RRHH_GuardarMiJornada',N'P') IS NULL OR OBJECT_ID(N'dbo.sp_RRHH_ResolverJornada',N'P') IS NULL THROW 55134,N'Faltan procedimientos de jornadas.',1;
SELECT MigrationId,FileSha256,Status,AppliedAtUtc FROM dbo.SchemaMigrationHistory WHERE MigrationId=N'0018_rrhh_attendance';
