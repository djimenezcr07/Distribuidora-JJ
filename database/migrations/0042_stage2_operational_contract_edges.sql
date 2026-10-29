SET NOCOUNT ON;SET XACT_ABORT ON;
IF SESSIONPROPERTY('QUOTED_IDENTIFIER')<>1 OR SESSIONPROPERTY('ANSI_NULLS')<>1 THROW 57610,N'Opciones SQL no acreditadas.',1;
DECLARE @Hash nvarchar(128)=N'$(MigrationSha256)';
IF LEN(@Hash)<>64 OR @Hash LIKE N'%[^0-9a-fA-F]%' THROW 57611,N'Hash no valido.',1;
IF EXISTS(SELECT 1 FROM dbo.SchemaMigrationHistory WHERE MigrationId=N'0042_stage2_operational_contract_edges')
BEGIN
 IF NOT EXISTS(SELECT 1 FROM dbo.SchemaMigrationHistory WHERE MigrationId=N'0042_stage2_operational_contract_edges' AND Status=N'Applied' AND FileSha256=UPPER(@Hash)) THROW 57612,N'Conflicto de ledger 0042.',1;
 RETURN;
END;
IF NOT EXISTS(SELECT 1 FROM dbo.SchemaMigrationHistory WHERE MigrationId=N'0040_stage2_document_ownership' AND Status=N'Applied') THROW 57613,N'Falta contrato Documents.',1;
DECLARE @Definition nvarchar(max)=OBJECT_DEFINITION(OBJECT_ID(N'dbo.sp_Stage2_CreateOrderAmountsV2'));
IF @Definition IS NULL OR CONVERT(varchar(64),HASHBYTES('SHA2_256',@Definition),2)<>N'FA33331B0C9B3E28BC26F07A58FB352DCF587373F59EFE09059464836E810264' THROW 57614,N'Contrato base monetario distinto del acreditado.',1;
IF OBJECT_ID(N'dbo.sp_Stage2_CreateOrderAmountsV2_1') IS NOT NULL OR OBJECT_ID(N'dbo.sp_Stage2_AuthorizeDocumentDownload') IS NOT NULL THROW 57615,N'Objetos anteriores no acreditados.',1;
DECLARE @Marker nvarchar(max)=N'              AND promotion.SegmentoCliente IN (N''Todos'', @Segmento)';
IF (LEN(@Definition)-LEN(REPLACE(@Definition,@Marker,N'')))/LEN(@Marker)<>1 THROW 57616,N'Punto de evolucion no acreditado.',1;
-- PromotionEngine skips a rounded-zero discount before claiming that product's benefit.
-- Extend the versioned SQL contract with that same eligibility, preserving priority/id ordering.
SET @Definition=REPLACE(@Definition,@Marker,@Marker+N'
              AND (promotion.Tipo<>N''DescuentoPorcentual'' OR ROUND(item.Cantidad *
                   (SELECT p.Precio FROM dbo.Productos p WITH(UPDLOCK,HOLDLOCK) WHERE p.ProductoId=item.ProductoId)
                   * promotion.PorcentajeDescuento / 100.0,2)>0)');
SET @Definition=REPLACE(@Definition,N'dbo.sp_Stage2_CreateOrderAmountsV2',N'dbo.sp_Stage2_CreateOrderAmountsV2_1');
BEGIN TRY BEGIN TRANSACTION;
 DECLARE @Lock int;EXEC @Lock=sys.sp_getapplock @Resource=N'Stage2:0042:install',@LockMode=N'Exclusive',@LockOwner=N'Transaction',@LockTimeout=10000;
 IF @Lock<0 THROW 57617,N'Instalacion concurrente.',1;
 EXEC sys.sp_executesql @Definition;
 EXEC(N'CREATE PROCEDURE dbo.sp_Stage2_AuthorizeDocumentDownload
  @Actor int,@DocumentoId int,@DocumentoVersionId int=NULL,@UsuarioId int,@PuedeAdministrar bit=0
 AS BEGIN
  SET NOCOUNT ON;SET XACT_ABORT ON;
  IF @@TRANCOUNT=0 OR @Actor<>@UsuarioId THROW 57401,N''Documento no disponible.'',1;
  DECLARE @Files TABLE(VersionId int,StorageKey nvarchar(80),OriginalName nvarchar(255),MimeType nvarchar(100));
  INSERT @Files EXEC dbo.sp_Stage2_Document_GetFileMetadata @Actor=@Actor,@DocumentoId=@DocumentoId,@DocumentoVersionId=@DocumentoVersionId,@UsuarioId=@UsuarioId,@PuedeAdministrar=0;
  IF EXISTS(SELECT 1 FROM @Files)
   INSERT dbo.DocumentoAuditoria(DocumentoId,Accion,UsuarioId,UsuarioNombre,Detalle)
   SELECT @DocumentoId,N''Autorizar descarga'',@Actor,NombreCompleto,N''Acceso del propietario acreditado; no afirma transferencia completa del archivo.'' FROM dbo.Usuarios WHERE UsuarioId=@Actor;
  SELECT VersionId,StorageKey,OriginalName,MimeType FROM @Files;
 END;');
 INSERT dbo.SchemaMigrationHistory(MigrationId,FileName,FileSha256,Status,AppliedBy,EnvironmentName,Notes)
 VALUES(N'0042_stage2_operational_contract_edges',N'0042_stage2_operational_contract_edges.sql',UPPER(@Hash),N'Applied',ORIGINAL_LOGIN(),DB_NAME(),N'Beneficio cero no consume prioridad; autorizacion de descarga auditada. Nuevos contratos, sin sobrescribir versiones anteriores.');
 COMMIT TRANSACTION;
END TRY BEGIN CATCH IF XACT_STATE()<>0 ROLLBACK TRANSACTION;THROW;END CATCH;
