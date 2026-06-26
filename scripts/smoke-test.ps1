# =============================================================
# Smoke test - Stack Zabbix + GLPI (Windows / Docker Desktop)
# Valida se os containers estao saudaveis e respondendo.
#
# Uso (na pasta docker\):
#   .\scripts\smoke-test.ps1
# =============================================================

$ErrorActionPreference = "Continue"

$DockerDir = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
Set-Location $DockerDir

$ZabbixUrl = if ($env:ZABBIX_URL) { $env:ZABBIX_URL } else { "http://localhost:80" }
$GlpiUrl   = if ($env:GLPI_URL)   { $env:GLPI_URL }   else { "http://localhost:8080" }

$script:Pass = 0
$script:Fail = 0
$script:Warn = 0

function Write-Ok    { param($msg) Write-Host "[OK] $msg" -ForegroundColor Green;  $script:Pass++ }
function Write-Fail  { param($msg) Write-Host "[FALHA] $msg" -ForegroundColor Red;    $script:Fail++ }
function Write-Warn  { param($msg) Write-Host "[AVISO] $msg" -ForegroundColor Yellow; $script:Warn++ }
function Write-Info  { param($msg) Write-Host "[INFO] $msg" -ForegroundColor Cyan }
function Write-Section { param($msg)
    Write-Host ""
    Write-Host "============================================" -ForegroundColor White
    Write-Host "  $msg" -ForegroundColor White
    Write-Host "============================================" -ForegroundColor White
}

# -- 1. Docker ---------------------------------------------------------------
Write-Section "1. Docker"

try {
    $dockerVersion = docker --version 2>&1
    Write-Ok "Docker instalado: $dockerVersion"
} catch {
    Write-Fail "Docker nao encontrado"
    exit 1
}

$dockerInfo = docker info 2>&1
if ($LASTEXITCODE -eq 0) {
    Write-Ok "Docker Desktop respondendo"
} else {
    Write-Fail "Docker daemon nao esta rodando - inicie o Docker Desktop"
    exit 1
}

# -- 2. Containers -----------------------------------------------------------
Write-Section "2. Containers"

$expected = @("zabbix-db", "zabbix-server", "zabbix-web", "glpi-db", "glpi")
foreach ($name in $expected) {
    $status = docker inspect -f "{{.State.Status}}" $name 2>$null
    if ($status -eq "running") {
        Write-Ok "Container $name esta running"
    } else {
        Write-Fail "Container ${name}: status=$status"
    }
}

# -- 3. Healthchecks ---------------------------------------------------------
Write-Section "3. Healthchecks dos bancos"

foreach ($name in @("zabbix-db", "glpi-db")) {
    $health = docker inspect -f "{{.State.Health.Status}}" $name 2>$null
    switch ($health) {
        "healthy"  { Write-Ok "$name -> healthy" }
        "starting" { Write-Warn "$name -> starting (aguarde ~30s e rode novamente)" }
        default    { Write-Fail "$name -> $health" }
    }
}

# -- 4. HTTP Zabbix ----------------------------------------------------------
Write-Section "4. Zabbix Web ($ZabbixUrl)"

try {
    $response = Invoke-WebRequest -Uri $ZabbixUrl -UseBasicParsing -TimeoutSec 10
    if ($response.StatusCode -in @(200, 302)) {
        Write-Ok "Zabbix respondeu HTTP $($response.StatusCode)"
    } else {
        Write-Fail "Zabbix HTTP $($response.StatusCode)"
    }
    if ($response.Content -match "zabbix") {
        Write-Ok "Pagina contem referencia ao Zabbix"
    } else {
        Write-Warn "Nao foi possivel confirmar conteudo Zabbix na pagina"
    }
} catch {
    Write-Fail "Zabbix inacessivel: $($_.Exception.Message)"
}

# -- 5. HTTP GLPI ------------------------------------------------------------
Write-Section "5. GLPI Web ($GlpiUrl)"

try {
    $response = Invoke-WebRequest -Uri $GlpiUrl -UseBasicParsing -TimeoutSec 10
    if ($response.StatusCode -in @(200, 302)) {
        Write-Ok "GLPI respondeu HTTP $($response.StatusCode)"
    } else {
        Write-Fail "GLPI HTTP $($response.StatusCode)"
    }
    if ($response.Content -match "glpi") {
        Write-Ok "Pagina contem referencia ao GLPI"
    } else {
        Write-Warn "Nao foi possivel confirmar conteudo GLPI na pagina"
    }
} catch {
    Write-Fail "GLPI inacessivel: $($_.Exception.Message)"
}

# -- 6. API Zabbix -----------------------------------------------------------
Write-Section "6. API Zabbix (login)"

$body = @{
    jsonrpc = "2.0"
    method  = "user.login"
    params  = @{ username = "Admin"; password = "zabbix" }
    id      = 1
} | ConvertTo-Json -Compress

$apiOk = $false
for ($i = 1; $i -le 6; $i++) {
    try {
        $apiResponse = Invoke-RestMethod -Uri "$ZabbixUrl/api_jsonrpc.php" `
            -Method Post -ContentType "application/json-rpc" -Body $body -TimeoutSec 10
        if ($apiResponse.result) {
            Write-Ok "Login API Admin/zabbix funcionou"
            $tokenPreview = $apiResponse.result.Substring(0, [Math]::Min(20, $apiResponse.result.Length))
            Write-Info "Token recebido: ${tokenPreview}..."
            $apiOk = $true
            break
        }
        if ($apiResponse.error.message -match "configuration") {
            Write-Warn "Zabbix ainda inicializando (tentativa $i/6)..."
            Start-Sleep -Seconds 15
        } else {
            Write-Fail "Falha no login da API: $($apiResponse.error.message)"
            break
        }
    } catch {
        Write-Warn "API indisponivel (tentativa $i/6): $($_.Exception.Message)"
        Start-Sleep -Seconds 15
    }
}
if (-not $apiOk -and $script:Fail -eq 0) {
    Write-Fail "API Zabbix nao respondeu apos 6 tentativas - aguarde e rode novamente"
}

# -- 7. Resumo ---------------------------------------------------------------
Write-Section "RESUMO"
Write-Host "  Passou:  $script:Pass"
Write-Host "  Falhou:  $script:Fail"
Write-Host "  Avisos:  $script:Warn"
Write-Host ""

if ($script:Fail -eq 0) {
    Write-Host "Stack operacional! Acesse:" -ForegroundColor Green
    Write-Host "  Zabbix -> $ZabbixUrl  (Admin / zabbix)"
    Write-Host "  GLPI   -> $GlpiUrl  (glpi / glpi)"
    exit 0
} else {
    Write-Host "Existem falhas. Veja docs/docker/TESTES.md para diagnostico." -ForegroundColor Red
    exit 1
}
