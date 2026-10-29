[CmdletBinding()]
param(
    [string]$ServerInstance = '(localdb)\MSSQLLocalDB',
    [switch]$KeepDatabase
)

$ErrorActionPreference = 'Stop'
$databaseName = 'TrilogiaMigrations_' + [Guid]::NewGuid().ToString('N')
$repoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path
$sqlcmd = Get-Command sqlcmd -ErrorAction Stop

function Invoke-SqlQuery {
    param([Parameter(Mandatory)][string]$Database,[Parameter(Mandatory)][string]$Query)
    & $sqlcmd.Path -S $ServerInstance -d $Database -E -I -b -Q $Query
    if ($LASTEXITCODE -ne 0) { throw "sqlcmd falló en $Database con código $LASTEXITCODE." }
}

function Invoke-SqlFile {
    param([Parameter(Mandatory)][string]$Database,[Parameter(Mandatory)][string]$RelativePath,[string]$HashOverride)
    $path = (Resolve-Path -LiteralPath (Join-Path $repoRoot $RelativePath)).Path
    $arguments = @('-S',$ServerInstance,'-d',$Database,'-E','-I','-b','-i',$path)
    if ($RelativePath -like 'database\migrations\*.sql' -and $RelativePath -notlike '*.verify.sql') {
        $hash = if ($PSBoundParameters.ContainsKey('HashOverride')) { $HashOverride } else { (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToUpperInvariant() }
        $arguments += @('-v',"MigrationSha256=$hash")
    }
    & $sqlcmd.Path @arguments
    if ($LASTEXITCODE -ne 0) { throw "Falló $RelativePath con código $LASTEXITCODE." }
}

function Invoke-SqlFileExpectFailure {
    param([Parameter(Mandatory)][string]$Database,[Parameter(Mandatory)][string]$RelativePath,[Parameter(Mandatory)][string]$Hash)
    $path = (Resolve-Path -LiteralPath (Join-Path $repoRoot $RelativePath)).Path
    & $sqlcmd.Path -S $ServerInstance -d $Database -E -I -b -i $path -v "MigrationSha256=$Hash" 2>&1 | Out-Null
    if ($LASTEXITCODE -eq 0) { throw "$RelativePath debía fallar y finalizó correctamente." }
}

try {
    Invoke-SqlQuery -Database 'master' -Query "IF CONVERT(INT,SERVERPROPERTY(N'IsLocalDB'))<>1 THROW 55410,N'El harness solo admite LocalDB.',1; CREATE DATABASE [$databaseName];"
    Invoke-SqlFile -Database $databaseName -RelativePath 'database\migrations\0001_create_schema_migration_history.sql'
    Invoke-SqlFile -Database $databaseName -RelativePath 'database\verify\0013_minimal_base_local.sql'
    Invoke-SqlFile -Database $databaseName -RelativePath 'database\verify\0013_0016_sequence_base_local.sql'

    Invoke-SqlFile -Database $databaseName -RelativePath 'database\migrations\0013_purchasing_suppliers_orders.sql'
    Invoke-SqlFile -Database $databaseName -RelativePath 'database\migrations\0013_purchasing_suppliers_orders.verify.sql'
    Invoke-SqlFile -Database $databaseName -RelativePath 'database\verify\0013_purchasing_functional_local.sql'

    Invoke-SqlFileExpectFailure -Database $databaseName -RelativePath 'database\migrations\0014_delivery_board_permission.sql' -Hash 'INVALID'
    Invoke-SqlQuery -Database $databaseName -Query "IF EXISTS(SELECT 1 FROM dbo.SchemaMigrationHistory WHERE MigrationId=N'0014_delivery_board_permission') OR EXISTS(SELECT 1 FROM dbo.Permisos WHERE Codigo=N'ENTREGAS_TABLERO_VER') THROW 55411,N'La ruta negativa de 0014 dejó cambios.',1;"

    foreach ($number in 14..16) {
        $prefix = '{0:D4}_' -f $number
        $matches = @(Get-ChildItem -LiteralPath (Join-Path $repoRoot 'database\migrations') -Filter "$prefix*.sql" | Where-Object { $_.Name -notlike '*.verify.sql' })
        if ($matches.Count -ne 1) { throw "No se encontró una única migración $prefix." }
        $migration = $matches[0]
        $relative = 'database\migrations\' + $migration.Name
        Invoke-SqlFile -Database $databaseName -RelativePath $relative
        Invoke-SqlFile -Database $databaseName -RelativePath ($relative -replace '\.sql$','.verify.sql')
    }

    Invoke-SqlQuery -Database $databaseName -Query "EXEC dbo.sp_Reportes_VentasDetallado @Desde='2026-01-01',@Hasta='2026-01-31',@Agrupacion=N'diario'; EXEC dbo.sp_Reportes_DesempenoVendedores @Desde='2026-01-01',@Hasta='2026-01-31'; EXEC dbo.sp_Ventas_CrossSellSuggestions @UsuarioId=NULL,@CartProductIds=N'1',@CandidateLimit=5;"

    foreach ($number in 13..16) {
        $prefix = '{0:D4}_' -f $number
        $matches = @(Get-ChildItem -LiteralPath (Join-Path $repoRoot 'database\migrations') -Filter "$prefix*.sql" | Where-Object { $_.Name -notlike '*.verify.sql' })
        if ($matches.Count -ne 1) { throw "No se encontró una única migración $prefix." }
        $migration = $matches[0]
        Invoke-SqlFileExpectFailure -Database $databaseName -RelativePath ('database\migrations\' + $migration.Name) -Hash (Get-FileHash -LiteralPath $migration.FullName -Algorithm SHA256).Hash.ToUpperInvariant()
        $rollback = [IO.Path]::ChangeExtension($migration.FullName,'rollback.md')
        if (-not (Test-Path -LiteralPath $rollback -PathType Leaf) -or (Get-Item -LiteralPath $rollback).Length -lt 80) { throw "Falta rollback documentado para $($migration.Name)." }
    }

    Invoke-SqlQuery -Database $databaseName -Query "DBCC CHECKDB([$databaseName]) WITH PHYSICAL_ONLY,NO_INFOMSGS; IF (SELECT COUNT(*) FROM dbo.SchemaMigrationHistory WHERE MigrationId BETWEEN N'0013' AND N'0016zzzz' AND Status=N'Applied')<>4 THROW 55412,N'Ledger incompleto.',1;"
    Write-Output "Harness 0013-0016 aprobado en ${databaseName}: migraciones, verify, flujo funcional, ruta negativa, segunda aplicación, rollback y CHECKDB."
}
finally {
    if (-not $KeepDatabase) {
        & $sqlcmd.Path -S $ServerInstance -d master -E -I -b -Q "IF DB_ID(N'$databaseName') IS NOT NULL BEGIN ALTER DATABASE [$databaseName] SET SINGLE_USER WITH ROLLBACK IMMEDIATE; DROP DATABASE [$databaseName]; END;"
        if ($LASTEXITCODE -ne 0) { Write-Warning "No se pudo eliminar la base desechable $databaseName." }
    }
    else { Write-Output "Base conservada por solicitud: $databaseName" }
}
