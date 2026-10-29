[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

function Assert-Condition {
    param(
        [Parameter(Mandatory)]
        [bool]$Condition,

        [Parameter(Mandatory)]
        [string]$Message
    )

    if (-not $Condition) {
        throw $Message
    }
}

$runnerPath = Join-Path $PSScriptRoot 'Invoke-Migration0012.ps1'
if (-not (Test-Path -LiteralPath $runnerPath -PathType Leaf)) {
    throw 'No se encontró Invoke-Migration0012.ps1.'
}

. $runnerPath

$migrationPath = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..\database\migrations\0012_inventory_combos_transformations_intelligence.sql')).Path
$migrationSha256 = ('A' * 64)
$entraArguments = @(New-SqlCmdArguments -ServerInstance 'server.example' -Database 'database' -MigrationPath $migrationPath -MigrationSha256 $migrationSha256 -AuthenticationMode Entra)
$windowsArguments = @(New-SqlCmdArguments -ServerInstance '(localdb)\TrilogiaSprint4Clean' -Database 'database' -MigrationPath $migrationPath -MigrationSha256 $migrationSha256 -AuthenticationMode Windows)

Assert-Condition -Condition (($entraArguments -contains '-G') -and -not ($entraArguments -contains '-E')) -Message 'El modo Entra debe construir -G y nunca -E.'
Assert-Condition -Condition (($windowsArguments -contains '-E') -and -not ($windowsArguments -contains '-G')) -Message 'El modo Windows debe construir -E y nunca -G.'
Assert-Condition -Condition (-not ($entraArguments -contains '-P') -and -not ($windowsArguments -contains '-P')) -Message 'El ejecutor no debe construir -P.'

$variableIndex = [Array]::IndexOf($entraArguments, '-v')
Assert-Condition -Condition ($variableIndex -ge 0 -and $entraArguments[$variableIndex + 1] -eq "MigrationSha256=$migrationSha256") -Message 'MigrationSha256 debe viajar como una sola asignación Nombre=Valor.'
Assert-Condition -Condition ((@($entraArguments | Where-Object { $_ -like 'MigrationSha256=*' })).Count -eq 1) -Message 'MigrationSha256 debe estar presente una única vez.'
Assert-Condition -Condition (-not ($entraArguments -contains '=') -and -not ($windowsArguments -contains '=')) -Message 'La asignación SQLCMD no debe fragmentarse.'

$invalidModeRejected = $false
try {
    New-SqlCmdArguments -ServerInstance 'server.example' -Database 'database' -MigrationPath $migrationPath -MigrationSha256 $migrationSha256 -AuthenticationMode Invalid | Out-Null
}
catch {
    $invalidModeRejected = $true
}
Assert-Condition -Condition $invalidModeRejected -Message 'Un AuthenticationMode inválido debe rechazarse.'

$emptyServerRejected = $false
try {
    New-SqlCmdArguments -ServerInstance '' -Database 'database' -MigrationPath $migrationPath -MigrationSha256 $migrationSha256 -AuthenticationMode Entra | Out-Null
}
catch {
    $emptyServerRejected = $true
}
Assert-Condition -Condition $emptyServerRejected -Message 'ServerInstance vacío debe rechazarse fuera de DryRun.'

$emptyDatabaseRejected = $false
try {
    New-SqlCmdArguments -ServerInstance 'server.example' -Database '' -MigrationPath $migrationPath -MigrationSha256 $migrationSha256 -AuthenticationMode Entra | Out-Null
}
catch {
    $emptyDatabaseRejected = $true
}
Assert-Condition -Condition $emptyDatabaseRejected -Message 'Database vacía debe rechazarse fuera de DryRun.'

$previousErrorActionPreference = $ErrorActionPreference
$ErrorActionPreference = 'Continue'
$missingBothOutput = & powershell -NoProfile -ExecutionPolicy Bypass -File $runnerPath -AuthenticationMode Windows 2>&1
$missingBothExitCode = $LASTEXITCODE
$missingDatabaseOutput = & powershell -NoProfile -ExecutionPolicy Bypass -File $runnerPath -ServerInstance 'server.example' -AuthenticationMode Entra 2>&1
$missingDatabaseExitCode = $LASTEXITCODE
$invalidRunnerModeOutput = & powershell -NoProfile -ExecutionPolicy Bypass -File $runnerPath -DryRun -AuthenticationMode Invalid 2>&1
$invalidRunnerModeExitCode = $LASTEXITCODE
$ErrorActionPreference = $previousErrorActionPreference

Assert-Condition -Condition ($missingBothExitCode -ne 0 -and ($missingBothOutput | Out-String) -match 'ServerInstance y Database son obligatorios') -Message 'El ejecutor debe rechazar ServerInstance y Database vacíos fuera de DryRun.'
Assert-Condition -Condition ($missingDatabaseExitCode -ne 0 -and ($missingDatabaseOutput | Out-String) -match 'ServerInstance y Database son obligatorios') -Message 'El ejecutor debe rechazar Database vacío fuera de DryRun.'
Assert-Condition -Condition ($invalidRunnerModeExitCode -ne 0) -Message 'El ejecutor debe rechazar AuthenticationMode inválido antes de abrir conexión.'

$escapedRunnerPath = $runnerPath.Replace("'", "''")
$dryRunOutput = & powershell -NoProfile -ExecutionPolicy Bypass -Command "& { function global:sqlcmd { throw 'DryRun intentó ejecutar sqlcmd.' }; & '$escapedRunnerPath' -DryRun -AuthenticationMode Windows }" 2>&1
if ($LASTEXITCODE -ne 0) {
    throw "El DryRun falló: $($dryRunOutput | Out-String)"
}

$dryRunText = $dryRunOutput | Out-String
Assert-Condition -Condition ($dryRunText -match 'SHA-256 de 0012 validado: [0-9A-F]{64}') -Message 'DryRun debe calcular un SHA-256 válido.'
Assert-Condition -Condition ($dryRunText -match 'Modo de autenticación: Windows') -Message 'DryRun debe informar el modo seleccionado.'
Assert-Condition -Condition ($dryRunText -match 'no se abrió conexión') -Message 'DryRun debe confirmar que no abrió conexión.'

$runnerSource = Get-Content -LiteralPath $runnerPath -Raw -Encoding utf8
Assert-Condition -Condition ($runnerSource -notmatch '(?m)(?<![A-Za-z0-9])-P(?![A-Za-z0-9])') -Message 'El ejecutor no debe contener el argumento -P.'
Assert-Condition -Condition ($runnerSource -notmatch '(?i)password') -Message 'El ejecutor no debe contener secretos embebidos.'

Write-Output 'Invoke-Migration0012 tests passed: Entra/Windows, SQLCMD variable, DryRun and guardrails.'
