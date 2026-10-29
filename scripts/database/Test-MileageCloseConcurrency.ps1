[CmdletBinding()]
param([string]$ServerInstance = '')

$ErrorActionPreference = 'Stop'
$sqlcmd = Get-Command sqlcmd -ErrorAction Stop
$repositoryRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$databaseName = 'Stage11Mileage_' + [Guid]::NewGuid().ToString('N').ToUpperInvariant()
if ($databaseName -notmatch '^Stage11Mileage_[0-9A-F]{32}$') { throw 'Nombre desechable inválido.' }
$localDbInstance = $null

if ([string]::IsNullOrWhiteSpace($ServerInstance)) {
    $localDb = Get-Command SqlLocalDB.exe -ErrorAction Stop
    $localDbInstance = 'Stage11Mileage' + [Guid]::NewGuid().ToString('N')
    if ($localDbInstance -notmatch '^Stage11Mileage[0-9a-f]{32}$') { throw 'Instancia LocalDB desechable inválida.' }
    & $localDb.Path create $localDbInstance | Out-Null
    if ($LASTEXITCODE -ne 0) { throw 'No se pudo crear la instancia LocalDB desechable.' }
    & $localDb.Path start $localDbInstance | Out-Null
    if ($LASTEXITCODE -ne 0) { throw 'No se pudo iniciar la instancia LocalDB desechable.' }
    $ServerInstance = "(localdb)\$localDbInstance"
}

function Invoke-SqlFile([string]$Database, [string]$RelativePath, [string[]]$Variables = @()) {
    $arguments = @('-S', $ServerInstance, '-d', $Database, '-E', '-I', '-b', '-i', (Join-Path $repositoryRoot $RelativePath))
    if ($Variables.Count -gt 0) { $arguments += @('-v') + $Variables }
    & $sqlcmd.Path @arguments
    if ($LASTEXITCODE -ne 0) { throw "sqlcmd falló al ejecutar $RelativePath." }
}

try {
    & $sqlcmd.Path -S $ServerInstance -d master -E -I -b -Q "CREATE DATABASE [$databaseName];"
    if ($LASTEXITCODE -ne 0) { throw 'No se pudo crear la base desechable.' }

    Invoke-SqlFile $databaseName 'database\verify\0024_concurrency_base_local.sql'
    Invoke-SqlFile $databaseName 'database\migrations\0001_create_schema_migration_history.sql'
    $migrationPath = Join-Path $repositoryRoot 'database\migrations\0024_stage1_ownership_security.sql'
    $migrationHash = (Get-FileHash -LiteralPath $migrationPath -Algorithm SHA256).Hash
    Invoke-SqlFile $databaseName 'database\migrations\0024_stage1_ownership_security.sql' @("MigrationSha256=$migrationHash")
    Invoke-SqlFile $databaseName 'database\migrations\0024_stage1_ownership_security.verify.sql'

    $sessionAPath = Join-Path $repositoryRoot 'database\verify\0024_concurrency_session_a.sql'
    $sessionBPath = Join-Path $repositoryRoot 'database\verify\0024_concurrency_session_b.sql'
    $runner = {
        param($SqlCmdPath, $Server, $Database, $InputFile)
        $output = & $SqlCmdPath -S $Server -d $Database -E -I -b -i $InputFile 2>&1 | Out-String
        [pscustomobject]@{ ExitCode = $LASTEXITCODE; Output = $output }
    }

    $sessionA = Start-Job -ScriptBlock $runner -ArgumentList $sqlcmd.Path, $ServerInstance, $databaseName, $sessionAPath
    Start-Sleep -Milliseconds 800
    $sessionB = Start-Job -ScriptBlock $runner -ArgumentList $sqlcmd.Path, $ServerInstance, $databaseName, $sessionBPath
    $resultA = Receive-Job -Job $sessionA -Wait -AutoRemoveJob
    $resultB = Receive-Job -Job $sessionB -Wait -AutoRemoveJob

    if ($resultA.ExitCode -ne 0 -or $resultA.Output -notmatch 'A_SUCCESS')
        { throw "La sesión A no cerró correctamente: $($resultA.Output)" }
    if ($resultB.ExitCode -eq 0 -or $resultB.Output -notmatch '53044')
        { throw "La sesión B no fue rechazada con el error de negocio 53044: $($resultB.Output)" }

    Invoke-SqlFile $databaseName 'database\verify\0024_concurrency_result_local.sql'
    Write-Host 'Concurrencia 0024 aprobada: A cerró, B recibió 53044 y el odómetro quedó en 150.'
}
finally {
    & $sqlcmd.Path -S $ServerInstance -d master -E -I -b -Q "IF DB_ID(N'$databaseName') IS NOT NULL BEGIN ALTER DATABASE [$databaseName] SET SINGLE_USER WITH ROLLBACK IMMEDIATE; DROP DATABASE [$databaseName]; END;" | Out-Null
    if ($localDbInstance) {
        & $localDb.Path stop $localDbInstance -k | Out-Null
        & $localDb.Path delete $localDbInstance | Out-Null
    }
}
