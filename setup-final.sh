#!/bin/bash
# setup-final.sh — aplica todas as configs do deepseek + terminal kali
set -e

echo "=== 1. Corrigindo fix-model.sh no container ==="
docker exec hermes-gateway sed -i 's/llama3\.1:latest/deepseek-r1:32b/g' /fix-model.sh
docker exec hermes-gateway grep "HERMES_MODEL" /fix-model.sh

echo ""
echo "=== 2. Aplicando config deepseek + terminal kali ==="
docker exec hermes-gateway python3 - << 'PYEOF'
import yaml, pathlib

cfg = pathlib.Path('/opt/data/config.yaml')
data = yaml.safe_load(cfg.read_text())

data['model']['default'] = 'deepseek-r1:32b'
data['model']['context_length'] = 131072
data['model']['provider'] = 'ollama'
data['model']['base_url'] = 'http://host.docker.internal:11434/v1'

data['terminal']['backend'] = 'docker'
data['terminal']['docker_image'] = 'kalilinux/kali-rolling'
data['terminal']['container_cpu'] = 4
data['terminal']['container_memory'] = 16384
data['terminal']['persistent_shell'] = True
data['terminal']['docker_extra_args'] = [
    '--cap-add=NET_ADMIN', '--cap-add=NET_RAW',
    '--cap-add=SYS_PTRACE', '--security-opt=seccomp=unconfined',
    '--network=host'
]
data['terminal']['docker_volumes'] = ['/opt/data/pentest:/pentest']
data['terminal']['docker_env'] = {
    'DEBIAN_FRONTEND': 'noninteractive',
    'PATH': '/root/go/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin'
}

pathlib.Path('/opt/data/context_length_cache.yaml').write_text('context_lengths: {}\n')
cfg.write_text(yaml.dump(data, allow_unicode=True, default_flow_style=False, sort_keys=False))

print(f"  model.default       : {data['model']['default']}")
print(f"  model.context_length: {data['model']['context_length']}")
print(f"  terminal.image      : {data['terminal']['docker_image']}")
print(f"  terminal.caps       : {data['terminal']['docker_extra_args']}")
print(f"  terminal.persistent : {data['terminal']['persistent_shell']}")
PYEOF

echo ""
echo "=== 3. Instalando ddgs (web search) ==="
docker exec hermes-gateway pip install ddgs -q 2>&1 | tail -2 || true

echo ""
echo "=== 4. Criando workspace de pentest ==="
docker exec hermes-gateway mkdir -p /opt/data/pentest
echo "  /opt/data/pentest criado"

echo ""
echo "=== 5. Verificando configuração final ==="
docker exec hermes-gateway python3 -c "
import yaml, pathlib
d = yaml.safe_load(pathlib.Path('/opt/data/config.yaml').read_text())
print('  modelo ativo:', d['model']['default'])
print('  context_len :', d['model']['context_length'])
print('  terminal    :', d['terminal']['docker_image'])
print('  caps        :', d['terminal']['docker_extra_args'])
"

echo ""
echo "=== 6. Commit e push ==="
git -C /mnt/c/Users/User/Downloads/hermes/hermes-uncensored add -A
git -C /mnt/c/Users/User/Downloads/hermes/hermes-uncensored commit -m "fix: deepseek-r1:32b ativo + kali terminal + caps de rede + SOUL.md corrigido" || echo "  (sem mudancas novas)"
git -C /mnt/c/Users/User/Downloads/hermes/hermes-uncensored push origin main 2>&1 | tail -3

echo ""
echo "=== 7. Teste final — deepseek respondendo ==="
API_KEY=$(grep VLLM_API_KEY /mnt/c/Users/User/Downloads/hermes/hermes-uncensored/config/.env | cut -d= -f2)
curl -s --max-time 90 -X POST http://localhost:8642/v1/chat/completions \
  -H "Authorization: Bearer $API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"model":"deepseek-r1:32b","messages":[{"role":"user","content":"Responda apenas: DEEPSEEK ATIVO E FUNCIONANDO"}],"max_tokens":15}' \
  | python3 -c "
import sys, json
d = json.load(sys.stdin)
if 'error' in d:
    print('ERRO:', d['error']['message'])
else:
    print('  Modelo:', d['model'])
    print('  Resposta:', d['choices'][0]['message']['content'])
"

echo ""
echo "=== CONCLUÍDO ==="
