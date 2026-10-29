[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$repositoryRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$baselinePath = Join-Path $repositoryRoot 'database\DistribuidoraJJ_DB.sql'
$expectedSha256 = '11625D764BFECD4BB86C932A5A6FA3ECCFC00CD4E62AEBF9B603D899828922B7'

if (-not (Test-Path -LiteralPath $baselinePath -PathType Leaf)) {
    throw 'No se encontró el baseline oficial.'
}

$actualSha256 = (Get-FileHash -LiteralPath $baselinePath -Algorithm SHA256).Hash.ToUpperInvariant()
if ($actualSha256 -ne $expectedSha256) {
    throw "El SHA-256 del baseline no coincide. Esperado: $expectedSha256; actual: $actualSha256."
}

$migrationFiles = Get-ChildItem -LiteralPath (Join-Path $repositoryRoot 'database\migrations') -Filter '*.sql' -File |
    Where-Object { $_.Name -match '^\d{4}_.+\.sql$' -and $_.Name -notmatch '\.verify\.sql$' } |
    Sort-Object Name
$actualIds = @($migrationFiles | ForEach-Object { [int]$_.Name.Substring(0, 4) })
$expectedIds = @(1..29)
if ($migrationFiles.Count -ne $expectedIds.Count -or
    (Compare-Object -ReferenceObject $expectedIds -DifferenceObject $actualIds).Count -ne 0) {
    throw 'La secuencia oficial de migraciones no es continua de 0001 a 0029.'
}

Write-Host "Baseline oficial verificado. SHA-256: $actualSha256. Migraciones ordenadas: $($migrationFiles.Count)."
