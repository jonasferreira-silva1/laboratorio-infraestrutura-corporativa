#!/usr/bin/env bash
# =============================================================
# Smoke test — Stack Zabbix + GLPI
# Valida se os containers estão saudáveis e respondendo.
#
# Uso (na pasta docker/):
#   chmod +x scripts/smoke-test.sh
#   ./scripts/smoke-test.sh
# =============================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOCKER_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$DOCKER_DIR"

ZABBIX_URL="${ZABBIX_URL:-http://localhost:80}"
GLPI_URL="${GLPI_URL:-http://localhost:8080}"

PASS=0
FAIL=0
WARN=0

green()  { printf "\033[0;32m[OK]\033[0m %s\n" "$1"; ((PASS++)) || true; }
red()    { printf "\033[0;31m[FALHA]\033[0m %s\n" "$1"; ((FAIL++)) || true; }
yellow() { printf "\033[0;33m[AVISO]\033[0m %s\n" "$1"; ((WARN++)) || true; }
info()   { printf "\033[0;36m[INFO]\033[0m %s\n" "$1"; }

section() {
  echo ""
  echo "============================================"
  echo "  $1"
  echo "============================================"
}

# ── 1. Docker disponível ─────────────────────────────────────
section "1. Docker"

if command -v docker &>/dev/null; then
  green "Docker instalado: $(docker --version)"
else
  red "Docker não encontrado no PATH"
  exit 1
fi

if docker info &>/dev/null; then
  green "Docker daemon respondendo"
else
  red "Docker daemon não está rodando"
  exit 1
fi

# ── 2. Containers ────────────────────────────────────────────
section "2. Containers"

EXPECTED=("zabbix-db" "zabbix-server" "zabbix-web" "glpi-db" "glpi")
for name in "${EXPECTED[@]}"; do
  status=$(docker inspect -f '{{.State.Status}}' "$name" 2>/dev/null || echo "missing")
  if [[ "$status" == "running" ]]; then
    green "Container $name está running"
  else
    red "Container $name: status=$status"
  fi
done

# ── 3. Healthchecks ──────────────────────────────────────────
section "3. Healthchecks dos bancos"

for name in zabbix-db glpi-db; do
  health=$(docker inspect -f '{{.State.Health.Status}}' "$name" 2>/dev/null || echo "none")
  if [[ "$health" == "healthy" ]]; then
    green "$name → healthy"
  elif [[ "$health" == "starting" ]]; then
    yellow "$name → starting (aguarde ~30s e rode novamente)"
  else
    red "$name → $health"
  fi
done

# ── 4. HTTP — Zabbix ─────────────────────────────────────────
section "4. Zabbix Web ($ZABBIX_URL)"

zabbix_code=$(curl -s -o /dev/null -w "%{http_code}" "$ZABBIX_URL" 2>/dev/null || echo "000")
if [[ "$zabbix_code" =~ ^(200|302)$ ]]; then
  green "Zabbix respondeu HTTP $zabbix_code"
else
  red "Zabbix HTTP $zabbix_code (esperado 200 ou 302)"
fi

if curl -s "$ZABBIX_URL" 2>/dev/null | grep -qi "zabbix"; then
  green "Página contém referência ao Zabbix"
else
  yellow "Não foi possível confirmar conteúdo Zabbix na página"
fi

# ── 5. HTTP — GLPI ───────────────────────────────────────────
section "5. GLPI Web ($GLPI_URL)"

glpi_code=$(curl -s -o /dev/null -w "%{http_code}" "$GLPI_URL" 2>/dev/null || echo "000")
if [[ "$glpi_code" =~ ^(200|302)$ ]]; then
  green "GLPI respondeu HTTP $glpi_code"
else
  red "GLPI HTTP $glpi_code (esperado 200 ou 302)"
fi

if curl -s "$GLPI_URL" 2>/dev/null | grep -qi "glpi"; then
  green "Página contém referência ao GLPI"
else
  yellow "Não foi possível confirmar conteúdo GLPI na página"
fi

# ── 6. API Zabbix ────────────────────────────────────────────
section "6. API Zabbix (login)"

api_body='{"jsonrpc":"2.0","method":"user.login","params":{"username":"Admin","password":"zabbix"},"id":1}'
api_ok=false

for i in 1 2 3 4 5 6; do
  api_response=$(curl -s -X POST "$ZABBIX_URL/api_jsonrpc.php" \
    -H "Content-Type: application/json-rpc" \
    -d "$api_body" 2>/dev/null || echo "")

  if echo "$api_response" | grep -q '"result"'; then
    green "Login API Admin/zabbix funcionou"
    token=$(echo "$api_response" | grep -o '"result":"[^"]*"' | head -1 | cut -d'"' -f4)
    info "Token recebido: ${token:0:20}..."
    api_ok=true
    break
  elif echo "$api_response" | grep -qi "configuration"; then
    yellow "Zabbix ainda inicializando (tentativa $i/6)..."
    sleep 15
  else
    red "Falha no login da API Zabbix"
    info "Resposta: $api_response"
    break
  fi
done

if [[ "$api_ok" == false ]] && [[ $FAIL -eq 0 ]]; then
  red "API Zabbix nao respondeu apos 6 tentativas - aguarde e rode novamente"
fi

# ── 7. Banco Zabbix ──────────────────────────────────────────
section "7. Banco de dados Zabbix"

zabbix_tables=$(docker exec zabbix-db mysql -uzabbix -p"${ZABBIX_DB_PASSWORD:-ZabbixDB@2024!}" \
  -N -e "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='zabbix';" 2>/dev/null || echo "0")

if [[ "$zabbix_tables" -gt 100 ]]; then
  green "Banco zabbix com $zabbix_tables tabelas (schema importado)"
else
  red "Banco zabbix com poucas tabelas ($zabbix_tables) — schema pode não ter sido criado"
fi

# ── 8. Banco GLPI ────────────────────────────────────────────
section "8. Banco de dados GLPI"

glpi_tables=$(docker exec glpi-db mariadb -uglpi -p"${GLPI_DB_PASSWORD:-GLPI@2024!}" \
  -N -e "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='glpi';" 2>/dev/null || echo "0")

if [[ "$glpi_tables" -gt 50 ]]; then
  green "Banco glpi com $glpi_tables tabelas (instalação concluída)"
elif [[ "$glpi_tables" -gt 0 ]]; then
  yellow "Banco glpi com $glpi_tables tabelas (instalação pode estar em andamento)"
else
  red "Banco glpi sem tabelas — aguarde o auto-install do GLPI (~2 min)"
fi

# ── 9. Conectividade interna ───────────────────────────────────
section "9. Rede interna entre containers"

if docker exec zabbix-web ping -c 1 -W 2 zabbix-server &>/dev/null; then
  green "zabbix-web alcança zabbix-server"
else
  yellow "Ping zabbix-web → zabbix-server falhou (pode estar desabilitado no container)"
fi

if docker exec glpi getent hosts glpi-db &>/dev/null; then
  green "glpi resolve hostname glpi-db"
else
  red "glpi não resolve glpi-db"
fi

# ── Resumo ───────────────────────────────────────────────────
section "RESUMO"
echo "  Passou:  $PASS"
echo "  Falhou:  $FAIL"
echo "  Avisos:  $WARN"
echo ""

if [[ "$FAIL" -eq 0 ]]; then
  echo "Stack operacional! Acesse:"
  echo "  Zabbix → $ZABBIX_URL  (Admin / zabbix)"
  echo "  GLPI   → $GLPI_URL  (glpi / glpi)"
  exit 0
else
  echo "Existem falhas. Veja docs/docker/TESTES.md para diagnóstico."
  exit 1
fi
