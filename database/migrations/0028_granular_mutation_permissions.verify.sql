SET NOCOUNT ON;

IF EXISTS (
    SELECT required.Codigo
    FROM (VALUES
        (N'CLIENTES_VER'), (N'CLIENTES_CREAR'), (N'CLIENTES_EDITAR'), (N'CLIENTES_INACTIVAR'),
        (N'CONSULTAS_VER'), (N'CONSULTAS_ATENDER'),
        (N'INVENTARIO_VER'), (N'INVENTARIO_CREAR'), (N'INVENTARIO_EDITAR'),
        (N'INVENTARIO_MOVIMIENTOS'), (N'INVENTARIO_ELIMINAR')
    ) required(Codigo)
    WHERE NOT EXISTS (SELECT 1 FROM dbo.Permisos permission WHERE permission.Codigo = required.Codigo AND permission.Activo = 1)
)
    THROW 55283, N'Faltan permisos granulares de 0028.', 1;

IF NOT EXISTS (
    SELECT 1 FROM dbo.SchemaMigrationHistory
    WHERE MigrationId = N'0028_granular_mutation_permissions' AND Status = N'Applied'
)
    THROW 55284, N'0028 no figura aplicada en el ledger.', 1;

SELECT MigrationId, FileName, FileSha256, Status, AppliedAtUtc
FROM dbo.SchemaMigrationHistory
WHERE MigrationId = N'0028_granular_mutation_permissions';
