#!/bin/bash
# ============================================================
# Hermes Uncensored — Restart Script
# Uso: bash restart.sh          (reinicia só hermes-gateway)
#      bash restart.sh full     (para tudo e sobe do zero)
# ============================================================
set -e
COMPOSE_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$COMPOSE_DIR"

echo "📁 Diretório: $COMPOSE_DIR"
echo ""

if [ "$1" = "full" ]; then
    echo "🛑 Parando todos os serviços..."
    docker compose down --remove-orphans
    echo ""
    echo "🏗️  Build + subida completa..."
    docker compose up -d --build
else
    echo "🛑 Parando hermes-gateway..."
    docker rm -f hermes-gateway 2>/dev/null || true
    echo ""
    echo "🏗️  Build + recriando hermes-gateway..."
    docker compose up -d --build hermes
fi

echo ""
echo "⏳ Aguardando 8 segundos para inicialização..."
sleep 8

echo ""
echo "📊 Status dos containers:"
docker compose ps

echo ""
echo "📋 Logs recentes (hermes-gateway):"
docker compose logs --tail=40 hermes

echo ""
echo "🔗 Links de acesso:"
echo "   Gateway WebUI : http://localhost:8081"
echo "   Gateway API   : http://localhost:5000"
echo "   vLLM API      : http://localhost:8000/v1/models"
echo ""
echo "✅ Pronto!"
