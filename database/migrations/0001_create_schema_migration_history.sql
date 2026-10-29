SET NOCOUNT ON;
SET XACT_ABORT ON;

BEGIN TRANSACTION;

IF OBJECT_ID(N'dbo.SchemaMigrationHistory', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.SchemaMigrationHistory
    (
        MigrationId NVARCHAR(150) NOT NULL,
        FileName NVARCHAR(260) NOT NULL,
        FileSha256 CHAR(64) NOT NULL,
        Status NVARCHAR(32) NOT NULL,
        AppliedAtUtc DATETIME2(0) NOT NULL
            CONSTRAINT DF_SchemaMigrationHistory_AppliedAtUtc DEFAULT SYSUTCDATETIME(),
        AppliedBy NVARCHAR(256) NOT NULL,
        EnvironmentName NVARCHAR(64) NOT NULL,
        Notes NVARCHAR(1000) NULL,
        CONSTRAINT PK_SchemaMigrationHistory PRIMARY KEY (MigrationId),
        CONSTRAINT CK_SchemaMigrationHistory_Status
            CHECK (Status IN (N'Applied', N'BaselineVerified', N'Failed', N'RolledBack'))
    );
END;

COMMIT TRANSACTION;
