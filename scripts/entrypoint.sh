#!/bin/bash
set -e

echo "🚀 Hermes Uncensored Starting..."

export HERMES_HOME=/opt/data
export HF_HOME=/opt/data/hf-cache
export VLLM_CACHE_ROOT=/opt/data/vllm-cache

mkdir -p /opt/data/logs /opt/data/hf-cache /opt/data/vllm-cache

if [ ! -f /opt/data/config.yaml ]; then
    echo "❌ config.yaml not found in /opt/data/config.yaml"
    exit 1
fi

# Ollama roda no host Windows — aguarda estar disponível
OLLAMA_URL="${OPENAI_BASE_URL:-http://host.docker.internal:11434/v1}"
echo "⏳ Waiting for Ollama at ${OLLAMA_URL}..."
for i in $(seq 1 30); do
    if curl -sf "${OLLAMA_URL}/models" > /dev/null 2>&1; then
        echo "✅ Ollama ready!"
        break
    fi
    sleep 2
    echo -n "."
done
echo ""

echo "🤖 Starting Hermes Gateway..."
cd /opt/hermes
exec python -m gateway.run --config /opt/data/config.yaml 2>&1 | tee /opt/data/logs/gateway.log
