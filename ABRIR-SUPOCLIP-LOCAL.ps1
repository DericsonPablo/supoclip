param(
    [switch]$Stop,
    [switch]$Status
)

$ErrorActionPreference = 'Stop'
$repo = $PSScriptRoot
$composeFile = Join-Path $repo 'docker-compose.pilot.yml'
$envFile = Join-Path $repo '.env.local'

if (-not (Test-Path -LiteralPath $composeFile)) { throw "Arquivo Compose ausente: $composeFile" }
if (-not (Test-Path -LiteralPath $envFile)) { throw "Configuração privada ausente: $envFile" }

$docker = (Get-Command docker -ErrorAction Stop).Source
$arguments = @('compose', '--env-file', $envFile, '-p', 'supoclip-pilot', '-f', $composeFile)

if ($Status) {
    & $docker @arguments ps
    exit $LASTEXITCODE
}

if ($Stop) {
    & $docker @arguments down
    exit $LASTEXITCODE
}

& $docker @arguments up -d --no-build
if ($LASTEXITCODE -ne 0) {
    throw 'O SupoClip local não iniciou. Confira os contêineres com -Status e o guia PILOTO-LOCAL.md.'
}

Start-Process 'http://127.0.0.1:3107/'
Write-Host 'SupoClip local: http://127.0.0.1:3107/'
