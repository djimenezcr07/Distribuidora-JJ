SET NOCOUNT ON;SET XACT_ABORT ON;
IF SESSIONPROPERTY('QUOTED_IDENTIFIER')<>1 OR SESSIONPROPERTY('ANSI_NULLS')<>1 THROW 57710,N'Opciones SQL no acreditadas.',1;
DECLARE @Hash nvarchar(128)=N'$(MigrationSha256)';
IF LEN(@Hash)<>64 OR @Hash LIKE N'%[^0-9a-fA-F]%' THROW 57711,N'Hash no valido.',1;
IF EXISTS(SELECT 1 FROM dbo.SchemaMigrationHistory WHERE MigrationId=N'0043_stage2_sales_report_amounts')
BEGIN
 IF NOT EXISTS(SELECT 1 FROM dbo.SchemaMigrationHistory WHERE MigrationId=N'0043_stage2_sales_report_amounts' AND Status=N'Applied' AND FileSha256=UPPER(@Hash)) THROW 57712,N'Conflicto de ledger 0043.',1;
 RETURN;
END;
IF NOT EXISTS(SELECT 1 FROM dbo.SchemaMigrationHistory WHERE MigrationId=N'0039_stage2_aggregate_amounts_v2' AND Status=N'Applied') THROW 57713,N'Falta contrato monetario.',1;
DECLARE @Definition nvarchar(max)=OBJECT_DEFINITION(OBJECT_ID(N'dbo.sp_Reportes_VentasDetallado'));
IF @Definition IS NULL OR CONVERT(varchar(64),HASHBYTES('SHA2_256',@Definition),2)<>N'C2DBB92C6B380824CE0EAE7EED82C0122691363B72A6B7CAC0BD5C73C28B47D0' THROW 57714,N'Reporte base distinto del acreditado.',1;
IF OBJECT_ID(N'dbo.sp_Stage2_ReportSalesAmountsV2') IS NOT NULL THROW 57715,N'Objeto anterior no acreditado.',1;
DECLARE @Old nvarchar(max)=N'INNER JOIN dbo.Productos product ON product.ProductoId=detail.ProductoId
        WHERE @Categoria IS NULL OR product.Categoria=@Categoria GROUP BY product.Categoria;';
-- Normalize line endings only to find the exact category branch. All filters and resultsets remain unchanged.
SET @Definition=REPLACE(@Definition,CHAR(13)+CHAR(10),CHAR(10));
SET @Old=REPLACE(@Old,CHAR(13)+CHAR(10),CHAR(10));
IF (LEN(@Definition)-LEN(REPLACE(@Definition,@Old,N'')))/LEN(@Old)<>1 THROW 57716,N'Rama de categoria no acreditada.',1;
SET @Definition=REPLACE(@Definition,@Old,N'INNER JOIN dbo.Productos product ON product.ProductoId=detail.ProductoId
        LEFT JOIN dbo.Stage2OrderAmountLines amount ON amount.PedidoId=eligible.PedidoId AND amount.LineKind=N''Producto''
            AND amount.ProductoId=detail.ProductoId AND amount.Cantidad=detail.Cantidad AND detail.PrecioUnitario>0
        WHERE @Categoria IS NULL OR product.Categoria=@Categoria GROUP BY product.Categoria;');
SET @Definition=REPLACE(@Definition,N'SUM(detail.Subtotal)',N'SUM(COALESCE(amount.Neto,detail.Subtotal))');
SET @Definition=REPLACE(@Definition,N'dbo.sp_Reportes_VentasDetallado',N'dbo.sp_Stage2_ReportSalesAmountsV2');
BEGIN TRY BEGIN TRANSACTION;
 DECLARE @Lock int;EXEC @Lock=sys.sp_getapplock @Resource=N'Stage2:0043:install',@LockMode=N'Exclusive',@LockOwner=N'Transaction',@LockTimeout=10000;
 IF @Lock<0 THROW 57717,N'Instalacion concurrente.',1;
 EXEC sys.sp_executesql @Definition;
 INSERT dbo.SchemaMigrationHistory(MigrationId,FileName,FileSha256,Status,AppliedBy,EnvironmentName,Notes)
 VALUES(N'0043_stage2_sales_report_amounts',N'0043_stage2_sales_report_amounts.sql',UPPER(@Hash),N'Applied',ORIGINAL_LOGIN(),DB_NAME(),N'Reporte por categoria: neto V2 persistido y fallback historico; filtros y resultsets conservados.');
 COMMIT TRANSACTION;
END TRY BEGIN CATCH IF XACT_STATE()<>0 ROLLBACK TRANSACTION;THROW;END CATCH;
