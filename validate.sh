#!/bin/bash
# Hermes Uncensored - Validation & Status Check Script

set -e

BLUE='\033[0;34m'
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${BLUE}╔══════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║   🤖 Hermes Uncensored - Validation Script               ║${NC}"
echo -e "${BLUE}╚══════════════════════════════════════════════════════════╝${NC}"
echo ""

# Check Docker
echo -e "${YELLOW}[1/5] Verificando Docker...${NC}"
if ! command -v docker &> /dev/null; then
    echo -e "${RED}✗ Docker não encontrado${NC}"
    exit 1
fi
DOCKER_VERSION=$(docker --version | grep -oE '[0-9]+\.[0-9]+\.[0-9]+')
echo -e "${GREEN}✓ Docker ${DOCKER_VERSION}${NC}"
echo ""

# Check Docker Compose
echo -e "${YELLOW}[2/5] Verificando Docker Compose...${NC}"
if ! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null; then
    echo -e "${RED}✗ Docker Compose não encontrado${NC}"
    exit 1
fi
COMPOSE_VERSION=$(docker compose version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1 || echo "Unknown")
echo -e "${GREEN}✓ Docker Compose ${COMPOSE_VERSION}${NC}"
echo ""

# Check containers
echo -e "${YELLOW}[3/5] Verificando Containers...${NC}"
cd "$(dirname "$0")/hermes-uncensored" 2>/dev/null || cd hermes-uncensored 2>/dev/null || true

if ! docker compose ps &> /dev/null; then
    echo -e "${RED}✗ Nenhum docker-compose.yml encontrado${NC}"
    exit 1
fi

VLLM_STATUS=$(docker compose ps vllm 2>/dev/null | grep -i "up" | wc -l)
HERMES_STATUS=$(docker compose ps hermes 2>/dev/null | grep -i "up" | wc -l)
UI_STATUS=$(docker compose ps ui 2>/dev/null | grep -i "up" | wc -l)

if [ $VLLM_STATUS -gt 0 ]; then
    echo -e "${GREEN}✓ vLLM (porta 8000) rodando${NC}"
else
    echo -e "${RED}✗ vLLM NÃO está rodando${NC}"
fi

if [ $HERMES_STATUS -gt 0 ]; then
    echo -e "${GREEN}✓ Hermes Gateway (porta 8642) rodando${NC}"
else
    echo -e "${RED}✗ Hermes Gateway NÃO está rodando${NC}"
fi

if [ $UI_STATUS -gt 0 ]; then
    echo -e "${GREEN}✓ Web UI (porta 3000) rodando${NC}"
else
    echo -e "${RED}✗ Web UI NÃO está rodando${NC}"
fi
echo ""

# Test APIs
echo -e "${YELLOW}[4/5] Testando Endpoints...${NC}"

# Test vLLM
if curl -sf -H "Authorization: Bearer hermes-local-secret-key" http://localhost:8000/v1/models > /dev/null 2>&1; then
    echo -e "${GREEN}✓ vLLM API respondendo${NC}"
else
    echo -e "${YELLOW}⚠ vLLM API não respondendo (ainda carregando? timeout de 5s)${NC}"
fi

# Test Gateway
if curl -sf -H "Authorization: Bearer hermes-local-secret-key" http://localhost:8642/v1/models > /dev/null 2>&1; then
    echo -e "${GREEN}✓ Gateway API respondendo${NC}"
else
    echo -e "${RED}✗ Gateway API NÃO respondendo${NC}"
fi

# Test UI
if curl -sf http://localhost:3000 > /dev/null 2>&1; then
    echo -e "${GREEN}✓ Web UI respondendo${NC}"
else
    echo -e "${RED}✗ Web UI NÃO respondendo${NC}"
fi
echo ""

# Show Docker stats
echo -e "${YELLOW}[5/5] Status dos Containers${NC}"
docker compose ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" 2>/dev/null || echo "Não foi possível obter status"
echo ""

# Summary
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}Resumo de Acesso:${NC}"
echo -e "  🌐 Web UI:       ${BLUE}http://localhost:3000${NC}"
echo -e "  🤖 API Gateway:  ${BLUE}http://localhost:8642/v1/chat/completions${NC}"
echo -e "  ⚙️  vLLM Direct:  ${BLUE}http://localhost:8000/v1/models${NC}"
echo -e "  🔑 Token:        ${BLUE}hermes-local-secret-key${NC}"
echo ""
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo ""

# Example curl
echo -e "${YELLOW}Exemplo de Requisição:${NC}"
echo -e "${BLUE}curl -X POST http://localhost:8642/v1/chat/completions \\${NC}"
echo -e "  ${BLUE}-H \"Authorization: Bearer hermes-local-secret-key\" \\${NC}"
echo -e "  ${BLUE}-H \"Content-Type: application/json\" \\${NC}"
echo -e "  ${BLUE}-d '{${NC}"
echo -e "    ${BLUE}\"model\": \"hermes-agent\",${NC}"
echo -e "    ${BLUE}\"messages\": [{\"role\": \"user\", \"content\": \"Oi!\"}],${NC}"
echo -e "    ${BLUE}\"max_tokens\": 100${NC}"
echo -e "  ${BLUE}}'${NC}"
echo ""

echo -e "${GREEN}✅ Validação concluída!${NC}"
