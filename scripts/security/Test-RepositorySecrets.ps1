[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repositoryRoot = (git rev-parse --show-toplevel).Trim()
$issues = [System.Collections.Generic.List[object]]::new()
$placeholderCount = 0
$scannedTextFiles = 0

function Test-ApprovedPlaceholder {
    param([AllowEmptyString()][string]$Value)

    if ($null -eq $Value) { return $true }

    $normalized = $Value.Trim().Trim('"').Trim("'").Trim()
    if ($normalized.Length -eq 0) { return $true }

    return $normalized -match '^(<[^>]+>|\$[A-Za-z_][A-Za-z0-9_]*|%[^%]+%|\$\{[^}]+\}|\*+|\[SECRETO DETECTADO\]|REDACTED|PLACEHOLDER)$'
}

function Test-HighEntropyCandidate {
    param([string]$Value)

    if ([string]::IsNullOrWhiteSpace($Value) -or $Value.Length -lt 20) { return $false }
    if ($Value -match '^(https?://|[A-Za-z]:\\|/|<|\$|%)') { return $false }

    $classes = 0
    if ($Value -cmatch '[a-z]') { $classes++ }
    if ($Value -cmatch '[A-Z]') { $classes++ }
    if ($Value -match '[0-9]') { $classes++ }
    if ($Value -match '[^A-Za-z0-9\s]') { $classes++ }
    return $classes -ge 3
}

function Add-Issue {
    param([string]$Path, [int]$Line, [string]$Type)

    $issues.Add([pscustomobject]@{ Path = $Path; Line = $Line; Type = $Type })
}

function Test-Candidate {
    param(
        [string]$Path,
        [int]$Line,
        [AllowEmptyString()][string]$Value,
        [string]$Type,
        [switch]$CheckEntropy
    )

    if (Test-ApprovedPlaceholder $Value) {
        $script:placeholderCount++
        return $false
    }

    if ($CheckEntropy -and -not (Test-HighEntropyCandidate $Value)) {
        return $false
    }

    Add-Issue $Path $Line $Type
    return $true
}

# The fragments are intentionally split so the scanner does not match its own source.
$bannedDemoPattern = '(?i)\b(12' + '34|admin' + '12' + '34?|nueva' + 'clave' + '123|token-de-' + 'recuperacion)\b'
$privateKeyPattern = '-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE ' + 'KEY-----'
$knownTokenPattern = '(?i)\b(?:gh[pousr]_[A-Za-z0-9]{30,}|AKIA[0-9A-Z]{16}|AIza[0-9A-Za-z_-]{30,}|xox[baprs]-[0-9A-Za-z-]{20,})\b'
$sensitiveNamePattern = '(?i)(?:password|passwd|pwd|contrasena|contrasenna|secret|client[_-]?secret|api[_-]?key|access[_-]?token|refresh[_-]?token|credential|connection[_-]?string|smtp[_-]?password)'

$trackedFiles = @(git -C $repositoryRoot ls-files)
foreach ($relativePath in $trackedFiles) {
    $fullPath = Join-Path $repositoryRoot $relativePath
    if (-not (Test-Path -LiteralPath $fullPath -PathType Leaf)) { continue }
    $extension = [System.IO.Path]::GetExtension($relativePath).ToLowerInvariant()
    $normalizedPath = $relativePath.Replace('\', '/')
    $isVendoredDependency = $normalizedPath -match '(^|/)wwwroot/lib/' -or $normalizedPath -match '\.min\.(js|css)$'

    $bytes = [System.IO.File]::ReadAllBytes($fullPath)
    if ($bytes -contains 0) { continue }

    $scannedTextFiles++
    $lineNumber = 0
    foreach ($line in [System.IO.File]::ReadLines($fullPath)) {
        $lineNumber++

        if ($line -match $privateKeyPattern) {
            Add-Issue $relativePath $lineNumber 'Clave privada'
            continue
        }

        if ($line -match $knownTokenPattern) {
            Add-Issue $relativePath $lineNumber 'Token de proveedor conocido'
            continue
        }

        if ($line -match $bannedDemoPattern) {
            Add-Issue $relativePath $lineNumber 'Credencial demo reutilizable'
            continue
        }

        $connectionMatch = [regex]::Match(
            $line,
            '(?i)(?:server|data source)\s*=.*?(?:password|pwd)\s*=\s*([^;"''\s]*)')
        if ($connectionMatch.Success) {
            if (Test-Candidate $relativePath $lineNumber $connectionMatch.Groups[1].Value 'Connection string con password') { continue }
        }

        $storageKeyMatch = [regex]::Match($line, '(?i)(?:AccountKey|SharedAccessSignature)\s*=\s*([^;"''\s]*)')
        if ($storageKeyMatch.Success) {
            if (Test-Candidate $relativePath $lineNumber $storageKeyMatch.Groups[1].Value 'Credencial de almacenamiento o Azure') { continue }
        }

        # JSON, JSON comentado, YAML and similar key/value literals.
        $structuredMatch = [regex]::Match(
            $line,
            '(?i)["'']?(password|passwd|pwd|newpassword|token|apikey|api[_-]?key|clientsecret|client[_-]?secret|access[_-]?token|refresh[_-]?token|contrasena|contrasenna|smtp[_-]?password)["'']?\s*[:=]\s*["'']([^"'']*)["'']')
        if (-not $isVendoredDependency -and $structuredMatch.Success) {
            if (Test-Candidate $relativePath $lineNumber $structuredMatch.Groups[2].Value 'Valor sensible en configuracion o ejemplo') { continue }
        }

        $xmlMatch = [regex]::Match(
            $line,
            '(?i)<(?:Password|Pwd|Token|ApiKey|ClientSecret|Contrasena|Contrasenna)>([^<]*)</')
        if (-not $isVendoredDependency -and $xmlMatch.Success) {
            if (Test-Candidate $relativePath $lineNumber $xmlMatch.Groups[1].Value 'Valor sensible en XML') { continue }
        }

        # Unquoted environment/YAML values. Code expressions containing punctuation are ignored.
        $plainAssignmentMatch = [regex]::Match(
            $line,
            '^\s*(?:[-]\s*)?["'']?(password|passwd|pwd|token|apikey|api[_-]?key|clientsecret|client[_-]?secret|contrasena|contrasenna|smtp[_-]?password)["'']?\s*[:=]\s*([^#;,\s]+)\s*$')
        if (-not $isVendoredDependency -and $plainAssignmentMatch.Success -and
            @('.yml', '.yaml', '.config', '.props', '.targets', '.toml', '.properties', '.env') -contains $extension) {
            $plainCandidate = $plainAssignmentMatch.Groups[2].Value
            if ($plainCandidate -notmatch '^[@{(]' -and
                (Test-Candidate $relativePath $lineNumber $plainCandidate 'Valor sensible sin comillas')) { continue }
        }

        # Additional entropy heuristic when a less conventional sensitive name is used.
        if (-not $isVendoredDependency -and $line -match $sensitiveNamePattern) {
            $entropyMatch = [regex]::Match(
                $line,
                '(?i)(?:password|passwd|pwd|contrasena|contrasenna|secret|client[_-]?secret|api[_-]?key|access[_-]?token|refresh[_-]?token|credential|connection[_-]?string|smtp[_-]?password)\s*[:=]\s*["'']([A-Za-z0-9+/=_\-.]{20,})["'']')
            if ($entropyMatch.Success) {
                if (Test-Candidate $relativePath $lineNumber $entropyMatch.Groups[1].Value 'Valor de alta entropia junto a nombre sensible' -CheckEntropy) { continue }
            }
        }
    }
}

if ($issues.Count -gt 0) {
    foreach ($issue in $issues) {
        Write-Error ("{0}:{1} [{2}] [SECRETO DETECTADO]" -f $issue.Path, $issue.Line, $issue.Type)
    }
    exit 1
}

Write-Host ("Secret scan passed. Tracked files reviewed: {0}; text files scanned: {1}; approved placeholders/empty values: {2}." -f $trackedFiles.Count, $scannedTextFiles, $placeholderCount)
