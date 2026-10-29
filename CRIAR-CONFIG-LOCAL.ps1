<#
.SYNOPSIS
Cria uma configuração privada para o piloto SupoClip, sem substituir a existente.
#>
[CmdletBinding()]
param(
    [string]$OutputPath = (Join-Path $PSScriptRoot '.env.local')
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$target = [IO.Path]::GetFullPath($OutputPath)
if (Test-Path -LiteralPath $target) {
    throw "Configuração já existe e foi preservada: $target"
}
if (-not (Test-Path -LiteralPath (Split-Path -Parent $target) -PathType Container)) {
    throw 'A pasta de destino da configuração não existe.'
}

$random = [Security.Cryptography.RandomNumberGenerator]::Create()
try {
    function New-HexSecret {
        $bytes = New-Object byte[] 32
        $random.GetBytes($bytes)
        return [BitConverter]::ToString($bytes).Replace('-', '').ToLowerInvariant()
    }

    $content = @(
        '# Generated locally for the isolated SupoClip pilot. Never commit this file.'
        "POSTGRES_PASSWORD=$(New-HexSecret)"
        "REDIS_PASSWORD=$(New-HexSecret)"
        "BETTER_AUTH_SECRET=$(New-HexSecret)"
        "BACKEND_AUTH_SECRET=$(New-HexSecret)"
        "APP_SETTINGS_ENCRYPTION_KEY=$(New-HexSecret)"
        'DISABLE_SIGN_UP=false'
    )
}
finally {
    $random.Dispose()
}

$created = $false
try {
    $stream = [IO.File]::Open($target, [IO.FileMode]::CreateNew,
                              [IO.FileAccess]::Write, [IO.FileShare]::None)
    $created = $true
    try {
        $writer = [IO.StreamWriter]::new($stream, [Text.UTF8Encoding]::new($false))
        try {
            foreach ($line in $content) { $writer.WriteLine($line) }
            $writer.Flush()
        }
        finally { $writer.Dispose() }
    }
    finally { $stream.Dispose() }
}
catch {
    if ($created -and (Test-Path -LiteralPath $target -PathType Leaf)) {
        Remove-Item -LiteralPath $target -Force
    }
    throw
}

Write-Host "Configuração privada criada: $target"
