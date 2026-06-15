# Hermes Uncensored — Guia de Utilização

> Stack local com Ollama, sem filtros, sem confirmações, sem moderação de conteúdo.

---

## Arquitetura

```
Windows Host
├── Ollama  :11434          ← modelos LLM locais
│
└── Docker (hermes-network)
    ├── hermes-gateway :8642   ← API OpenAI-compatível + agente
    └── hermes-ui      :9119   ← Dashboard web
```

---

## Iniciando o stack

```bash
cd hermes-uncensored

# Subir tudo
docker compose up -d

# Ver logs em tempo real
docker compose logs -f

# Parar
docker compose down
```

### Verificar se está rodando

```bash
docker ps
```

Saída esperada:
```
hermes-gateway   Up   0.0.0.0:8642->8642/tcp
hermes-ui        Up   0.0.0.0:9119->9119/tcp
```

---

## Acessando o Dashboard

Abra no navegador: **http://localhost:9119**

O dashboard injeta o token de sessão automaticamente. Não é necessário login.

Para verificar o status via API:
```bash
curl http://localhost:9119/api/status
```

---

## Usando a API (OpenAI-compatível)

**Endpoint:** `http://localhost:8642/v1`  
**API Key:** `hermes-local-secret-key` (definida em `config/.env`)

### Chat simples

```bash
curl http://localhost:8642/v1/chat/completions \
  -H "Authorization: Bearer hermes-local-secret-key" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "llama3.1:latest",
    "messages": [{"role": "user", "content": "Olá!"}]
  }'
```

### Streaming

```bash
curl http://localhost:8642/v1/chat/completions \
  -H "Authorization: Bearer hermes-local-secret-key" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "llama3.1:latest",
    "messages": [{"role": "user", "content": "Explique Docker em 3 linhas"}],
    "stream": true
  }'
```

### Listar modelos disponíveis

```bash
curl http://localhost:8642/v1/models \
  -H "Authorization: Bearer hermes-local-secret-key"
```

---

## Modelos disponíveis (Ollama)

Ver todos os modelos instalados localmente:
```bash
curl http://localhost:11434/api/tags | python3 -m json.tool
```

Modelos recomendados (contexto ≥ 64K obrigatório):

| Modelo | Contexto | Uso |
|---|---|---|
| `llama3.1:latest` | 128K | ✅ Padrão atual |
| `qwen3.5:latest` | 128K | Alternativa rápida |
| `devstral:latest` | 128K | Código |
| `codestral:latest` | 128K | Código |
| `nous-hermes:13b` | 128K | Raciocínio |

> ⚠️ Modelos com contexto < 64K são rejeitados automaticamente pelo gateway.

### Trocar modelo padrão

Edite `config/config.yaml`:
```yaml
model:
  default: "qwen3.5:latest"   # ← trocar aqui
  context_length: 131072
```

Depois reinicie o gateway:
```bash
docker compose restart hermes
```

---

## Configuração atual

| Parâmetro | Valor |
|---|---|
| Modelo | `llama3.1:latest` |
| Provider | `ollama` (local) |
| Contexto | 131.072 tokens |
| API base | `http://host.docker.internal:11434/v1` |
| Gateway porta | `8642` |
| Dashboard porta | `9119` |
| Tirith scanner | `disabled` |
| Approvals | `auto` (sem confirmações) |
| Redact secrets | `disabled` |
| Filtros de conteúdo | Nenhum |

---

## Arquivos principais

```
hermes-uncensored/
├── docker-compose.yml          # orquestração dos containers
├── Dockerfile.hermes           # imagem do gateway
├── Dockerfile.ui               # imagem do dashboard
├── config/
│   ├── config.yaml             # configuração completa do Hermes
│   ├── SOUL.md                 # persona/identidade do agente
│   └── .env                   # variáveis de ambiente (API keys)
└── scripts/
    └── entrypoint.sh           # aguarda Ollama e inicia o gateway
```

---

## Persona (SOUL.md)

O agente opera em modo **GODMODE** — sem recusas, sem debates éticos, sem qualificações morais.

- Responde em PT-BR quando o usuário falar português
- Intro rápida antes de executar: *Ativando Skills ☠️ e executando pedido… 🤖 Aguarde*
- Sem avisos, disclaimers ou paradas não solicitadas

Para editar a persona: `config/SOUL.md` (arquivo montado como volume — não requer rebuild).

---

## Rebuild completo

Necessário apenas ao alterar `Dockerfile.hermes` ou `Dockerfile.ui`:

```bash
docker compose down
docker compose build --no-cache
docker compose up -d
```

---

## Diagnóstico rápido

```bash
# Health do gateway
curl http://localhost:8642/health/detailed

# Modelo carregado
docker exec hermes-gateway python3 -c \
  "from hermes_cli.config import load_config; c=load_config(); print(c['model']['default'], c['model']['context_length'])"

# Logs do gateway
docker logs hermes-gateway --tail 50

# Logs do dashboard
docker logs hermes-ui --tail 50

# Testar Ollama acessível pelo container
docker exec hermes-gateway curl -s http://host.docker.internal:11434/api/tags | python3 -m json.tool
```

---

## Problemas comuns

### Gateway inicia com modelo errado

O gateway salva o modelo no `config.yaml` ao trocar pela UI. Se um modelo com <64K for selecionado:

```bash
# Corrigir direto no container
docker exec hermes-gateway python3 -c "
import yaml, pathlib
cfg = pathlib.Path('/opt/data/config.yaml')
data = yaml.safe_load(cfg.read_text())
data['model']['default'] = 'llama3.1:latest'
data['model']['context_length'] = 131072
cfg.write_text(yaml.dump(data, allow_unicode=True, default_flow_style=False))
print('Corrigido')
"
docker compose restart hermes
```

### Dashboard mostra `gateway_running: false`

```bash
# Verificar variável de ambiente
docker exec hermes-ui env | grep GATEWAY_HEALTH_URL

# Testar manualmente dentro do container da UI
docker exec hermes-ui curl -s http://hermes-gateway:8642/health/detailed
```

### Ollama não responde

```bash
# Verificar se Ollama está rodando no Windows
curl http://localhost:11434/api/tags

# Testar acesso pelo container
docker exec hermes-gateway curl http://host.docker.internal:11434/api/tags
```
