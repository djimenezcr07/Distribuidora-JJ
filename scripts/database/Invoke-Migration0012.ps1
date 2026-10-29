[CmdletBinding()]
param(
    [string]$ServerInstance,
    [string]$Database,
    [ValidateSet('Entra', 'Windows')]
    [string]$AuthenticationMode = 'Entra',
    [switch]$DryRun
)

$ErrorActionPreference = 'Stop'

function New-SqlCmdArguments {
    [OutputType([string[]])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$ServerInstance,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Database,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$MigrationPath,

        [Parameter(Mandatory)]
        [ValidatePattern('^[0-9A-F]{64}$')]
        [string]$MigrationSha256,

        [Parameter(Mandatory)]
        [ValidateSet('Entra', 'Windows')]
        [string]$AuthenticationMode
    )

    $authenticationArgument = if ($AuthenticationMode -eq 'Entra') { '-G' } else { '-E' }
    return @(
        '-S', $ServerInstance,
        '-d', $Database,
        $authenticationArgument,
        '-I',
        '-b',
        '-i', $MigrationPath,
        '-v', "MigrationSha256=$MigrationSha256"
    )
}

if ($MyInvocation.InvocationName -eq '.') {
    return
}

$unresolvedMigrationPath = Join-Path $PSScriptRoot '..\..\database\migrations\0012_inventory_combos_transformations_intelligence.sql'
if (-not (Test-Path -LiteralPath $unresolvedMigrationPath -PathType Leaf)) {
    throw 'No se encontró el archivo de migración 0012.'
}

$migrationPath = (Resolve-Path -LiteralPath $unresolvedMigrationPath).Path
$migrationSha256 = (Get-FileHash -LiteralPath $migrationPath -Algorithm SHA256).Hash
if ([string]::IsNullOrWhiteSpace($migrationSha256)) {
    throw 'No fue posible calcular el SHA-256 de la migración 0012.'
}
$migrationSha256 = $migrationSha256.ToUpperInvariant()

if ($migrationSha256 -notmatch '^[0-9A-F]{64}$') {
    throw 'No fue posible calcular un SHA-256 hexadecimal válido para la migración 0012.'
}

if ($DryRun) {
    Write-Output "Ruta de 0012: $migrationPath"
    Write-Output "SHA-256 de 0012 validado: $migrationSha256"
    Write-Output "Modo de autenticación: $AuthenticationMode"
    Write-Output 'DryRun completado: no se abrió conexión.'
    return
}

if ([string]::IsNullOrWhiteSpace($ServerInstance) -or [string]::IsNullOrWhiteSpace($Database)) {
    throw 'ServerInstance y Database son obligatorios salvo en modo -DryRun.'
}

$sqlcmd = Get-Command sqlcmd -ErrorAction SilentlyContinue
if ($null -eq $sqlcmd) {
    throw 'sqlcmd no está disponible en PATH.'
}

$sqlcmdArguments = New-SqlCmdArguments `
    -ServerInstance $ServerInstance `
    -Database $Database `
    -MigrationPath $migrationPath `
    -MigrationSha256 $migrationSha256 `
    -AuthenticationMode $AuthenticationMode

& $sqlcmd.Path @sqlcmdArguments

if ($LASTEXITCODE -ne 0) {
    throw "sqlcmd finalizó con código $LASTEXITCODE al ejecutar 0012."
}

Write-Output 'Migración 0012 ejecutada correctamente.'
