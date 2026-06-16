#!/bin/bash
# switch-model.sh — troca o modelo ativo do Hermes Agent
# Uso: ./switch-model.sh [nome_do_modelo]
# Ex:  ./switch-model.sh devstral:latest
#      ./switch-model.sh deepseek-r1:32b
#      ./switch-model.sh qwen3.5:latest

set -e

WIN_IP=$(ip route | grep default | awk '{print $3}' | head -1)
OLLAMA_URL="http://${WIN_IP}:11434"

list_models() {
    echo ""
    echo "╔══════════════════════════════════════════════════════════╗"
    echo "║          MODELOS DISPONÍVEIS NO OLLAMA LOCAL             ║"
    echo "╠══════════════════════════════════════════════════════════╣"
    curl -s --max-time 5 "${OLLAMA_URL}/api/tags" | python3 -c "
import sys, json
try:
    models = [m for m in json.load(sys.stdin)['models'] if m['size']]
    for i, m in enumerate(models):
        gb = m['size']/1e9
        params = m['details'].get('parameter_size','?')
        quant = m['details'].get('quantization_level','')
        print(f'║  [{i+1:2}] {m[\"name\"]:<38} {params:<6} {gb:.1f}GB ║')
except Exception as e:
    print(f'║  Erro: {e}')
print('╚══════════════════════════════════════════════════════════╝')
"
    echo ""
}

apply_model() {
    local MODEL="$1"
    docker exec hermes-gateway python3 -c "
import yaml, pathlib
cfg = pathlib.Path('/opt/data/config.yaml')
data = yaml.safe_load(cfg.read_text())
old = data['model']['default']
data['model']['default'] = '$MODEL'
data['model']['context_length'] = 131072
data['model']['base_url'] = 'http://host.docker.internal:11434/v1'
data['model']['provider'] = 'ollama'
pathlib.Path('/opt/data/context_length_cache.yaml').write_text('context_lengths: {}\n')
cfg.write_text(yaml.dump(data, allow_unicode=True, default_flow_style=False, sort_keys=False))
print(f'  Antes:  {old}')
print(f'  Agora:  {data[\"model\"][\"default\"]}')
"
}

if [ -z "$1" ]; then
    list_models
    echo "Uso: $0 <modelo>"
    echo ""
    CURRENT=$(docker exec hermes-gateway python3 -c "
import yaml,pathlib
d=yaml.safe_load(pathlib.Path('/opt/data/config.yaml').read_text())
print('  Modelo atual:', d['model']['default'])
" 2>/dev/null)
    echo "$CURRENT"
    exit 0
fi

echo ""
echo "🔄 Trocando modelo..."
apply_model "$1"
echo "✅ Pronto! Próxima conversa usará: $1"
echo ""
