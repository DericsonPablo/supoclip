<#
.SYNOPSIS
Baixa os modelos do piloto para volumes Docker, antes de importar vídeos pessoais.

.DESCRIPTION
Somente este projeto Compose é interrompido durante o download. Se o antivírus
do Windows interceptar TLS, acrescenta a CA pública já confiada pelo Windows
ao pacote de CAs da imagem Ollama, sem desativar a verificação do certificado.
#>
[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $false

$repo = $PSScriptRoot
$composeFile = Join-Path $repo 'docker-compose.pilot.yml'
$envFile = Join-Path $repo '.env.local'
$ollamaImage = 'ollama/ollama@sha256:dea72d1e22270fe095b68fdf756d2b489d615643c5a2eaebbc5f569181e322d8'
$ollamaModel = 'qwen2.5:7b-instruct'
$docker = (Get-Command docker -ErrorAction Stop).Source
$composeArgs = @('compose', '--env-file', $envFile, '-p', 'supoclip-pilot', '-f', $composeFile)

if (-not (Test-Path -LiteralPath $composeFile -PathType Leaf)) { throw "Arquivo Compose ausente: $composeFile" }
if (-not (Test-Path -LiteralPath $envFile -PathType Leaf)) { throw "Configuração privada ausente: $envFile" }

& $docker @composeArgs config --quiet
if ($LASTEXITCODE -ne 0) { throw 'Configuração Compose inválida.' }

function Test-ServiceRunning([string]$service) {
    $containerId = & $docker @composeArgs ps -q $service
    if ($LASTEXITCODE -ne 0) { throw "Não foi possível consultar o serviço $service." }
    if (-not $containerId) { return $false }
    $running = & $docker inspect --format '{{.State.Running}}' ($containerId | Select-Object -First 1)
    if ($LASTEXITCODE -ne 0) { throw "Não foi possível conferir o contêiner $service." }
    return ($running -eq 'true')
}

function Invoke-OllamaPull([string]$caBundle = '') {
    $pullScript = 'ollama serve >/tmp/ollama.log 2>&1 & sleep 3; ollama pull qwen2.5:7b-instruct >/tmp/pull.log 2>&1; result=$?; tail -c 1200 /tmp/pull.log; exit $result'
    $dockerArgs = @('run', '--rm', '--network', 'bridge', '--volume', 'supoclip-pilot_ollama_models:/root/.ollama')
    if ($caBundle) {
        $dockerArgs += @('--volume', "${caBundle}:/tmp/pilot-ca.crt:ro", '--env', 'SSL_CERT_FILE=/tmp/pilot-ca.crt')
    }
    $dockerArgs += @('--entrypoint', '/bin/sh', $ollamaImage, '-c', $pullScript)
    $output = & $docker @dockerArgs 2>&1
    return [pscustomobject]@{ ExitCode = $LASTEXITCODE; Output = ($output -join "`n") }
}

function New-TrustedCaBundle {
    $trusted = @(
        Get-ChildItem Cert:\LocalMachine\Root, Cert:\CurrentUser\Root -ErrorAction SilentlyContinue |
            Where-Object {
                $_.Subject -eq 'CN=Kaspersky Anti-Virus Personal Root Certificate, O=AO Kaspersky Lab' -and
                $_.NotBefore -le (Get-Date) -and $_.NotAfter -gt (Get-Date)
            } | Sort-Object Thumbprint -Unique
    )
    if ($trusted.Count -ne 1) {
        throw 'Falha TLS: não foi encontrada uma única CA pública e válida do Kaspersky no repositório de raízes confiáveis do Windows.'
    }

    $bundle = Join-Path ([IO.Path]::GetTempPath()) ("supoclip-pilot-ca-$([Guid]::NewGuid().ToString('N')).crt")
    $containerId = & $docker create --entrypoint /bin/sh $ollamaImage -c true
    if ($LASTEXITCODE -ne 0) { throw 'Não foi possível acessar o pacote de certificados da imagem Ollama.' }
    try {
        & $docker cp "${containerId}:/etc/ssl/certs/ca-certificates.crt" $bundle | Out-Null
        if ($LASTEXITCODE -ne 0) { throw 'Não foi possível copiar o pacote de certificados da imagem Ollama.' }
    }
    finally {
        & $docker rm $containerId | Out-Null
    }

    # RawData contém somente o certificado público, nunca a chave privada.
    $base64 = [Convert]::ToBase64String($trusted[0].RawData)
    $lines = [regex]::Matches($base64, '.{1,64}') | ForEach-Object Value
    $pem = "`n-----BEGIN CERTIFICATE-----`n" + ($lines -join "`n") + "`n-----END CERTIFICATE-----`n"
    [IO.File]::AppendAllText($bundle, $pem, [Text.Encoding]::ASCII)
    return $bundle
}

function Short-Error([string]$message) {
    if ($message.Length -gt 500) { return $message.Substring($message.Length - 500) }
    return $message
}

$ollamaWasRunning = Test-ServiceRunning 'ollama'
$workerWasRunning = Test-ServiceRunning 'worker'
$bundlePath = ''
$failure = $null
$restoreErrors = [System.Collections.Generic.List[string]]::new()

try {
    & $docker @composeArgs stop worker ollama | Out-Null
    if ($LASTEXITCODE -ne 0) { throw 'Não foi possível parar worker/Ollama do piloto.' }

    Write-Host "Preparando $ollamaModel no volume local do piloto..."
    $pull = Invoke-OllamaPull
    if ($pull.ExitCode -ne 0) {
        if ($pull.Output -notmatch 'x509: certificate signed by unknown authority') {
            throw ('Falha no download Ollama: ' + (Short-Error $pull.Output))
        }
        Write-Host 'O antivírus interceptou TLS; usando a CA pública já confiada pelo Windows.'
        $bundlePath = New-TrustedCaBundle
        $pull = Invoke-OllamaPull $bundlePath
        if ($pull.ExitCode -ne 0) {
            throw ('Falha no download Ollama com TLS verificado: ' + (Short-Error $pull.Output))
        }
    }
    Write-Host "Modelo Ollama pronto: $ollamaModel"

    Write-Host 'Preparando Whisper base no volume local do piloto...'
    & $docker run --rm --network bridge --volume 'supoclip-pilot_whisper_models:/root/.cache/whisper' 'supoclip-pilot-backend:local' '.venv/bin/python' '-c' "import whisper; assert hasattr(whisper, 'load_model'); whisper.load_model('base')" | Out-Null
    if ($LASTEXITCODE -ne 0) { throw 'Falha ao preparar Whisper base.' }
    Write-Host 'Whisper base pronto.'
}
catch {
    $failure = $_
}
finally {
    if ($bundlePath -and (Test-Path -LiteralPath $bundlePath -PathType Leaf)) {
        Remove-Item -LiteralPath $bundlePath -Force
    }
    if ($ollamaWasRunning) {
        & $docker @composeArgs start ollama | Out-Null
        if ($LASTEXITCODE -ne 0) { $restoreErrors.Add('Ollama não reiniciou.') }
    }
    if ($workerWasRunning) {
        & $docker @composeArgs start worker | Out-Null
        if ($LASTEXITCODE -ne 0) { $restoreErrors.Add('Worker não reiniciou.') }
    }
}

if ($failure) { throw $failure }
if ($restoreErrors.Count) { throw ($restoreErrors -join ' ') }
Write-Host 'Modelos locais preparados; o estado anterior dos serviços foi restaurado.'
