#!/bin/bash
# fix-model.sh — força llama3.1:latest e limpa qualquer modelo inválido do /opt/data
set -e

MODEL="${HERMES_MODEL:-devstral:latest}"
CONTEXT="${HERMES_CONTEXT:-131072}"
BASE_URL="${OPENAI_BASE_URL:-http://host.docker.internal:11434/v1}"

echo "🔧 Corrigindo modelo para: $MODEL (ctx: $CONTEXT)"

python3 - <<PYEOF
import yaml, pathlib, sys

model = "$MODEL"
context = $CONTEXT
base_url = "$BASE_URL"

cfg_path = pathlib.Path("/opt/data/config.yaml")
if not cfg_path.exists():
    print("config.yaml não encontrado — pulando")
    sys.exit(0)

data = yaml.safe_load(cfg_path.read_text()) or {}

# Modelo principal
data.setdefault("model", {})
data["model"]["default"] = model
data["model"]["context_length"] = context
data["model"]["base_url"] = base_url

# Todos os auxiliares
for section in data.get("auxiliary", {}):
    aux = data["auxiliary"][section]
    if isinstance(aux, dict) and aux.get("provider") not in ("auto", ""):
        if aux.get("model") and ("VISHNUDHAT" in aux["model"] or "DeepHat" in aux["model"] or not aux["model"]):
            aux["model"] = model
            aux["base_url"] = base_url

cfg_path.write_text(yaml.dump(data, allow_unicode=True, default_flow_style=False, sort_keys=False))

# Limpar cache de context_length
cache = pathlib.Path("/opt/data/context_length_cache.yaml")
cache.write_text(yaml.dump({"context_lengths": {}}, default_flow_style=False))

bad = str(data).count("VISHNUDHAT") + str(data).count("DeepHat")
print(f"✅ Modelo definido: {data['model']['default']} | ctx: {data['model']['context_length']} | refs inválidas: {bad}")
PYEOF
