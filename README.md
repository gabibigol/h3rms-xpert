# Hermes Uncensored 🤖☠️

Stack de IA local com [Hermes Agent](https://github.com/NousResearch/hermes-agent) + [vLLM](https://github.com/vllm-project/vllm), orquestrada via Docker Compose.  
Integração com Telegram, API REST e WebUI local.

---

## Arquitetura

```
[Você / Telegram]
       │
       ▼
hermes-gateway  (porta 8081 WebUI | 5000 API)
  Python 3.11 · NousResearch/hermes-agent
       │  http://vllm:8000/v1
       ▼
hermes-vllm     (porta 8000)
  vllm/vllm-openai · facebook/opt-1.3b (GPU fp16)
       │
  Rede Docker: hermes-network (172.19.0.0/16)
```

---

## Pré-requisitos

| Requisito | Detalhe |
|---|---|
| Docker Desktop | WSL2 + GPU habilitados |
| GPU NVIDIA | CUDA ≥ 12 (driver ≥ 535) |
| VRAM | ≥ 4 GB (opt-1.3b) |
| RAM | ≥ 8 GB |
| Disco | ≥ 20 GB livres em `/opt/data` |

---

## Estrutura do projeto

```
hermes-uncensored/
├── docker-compose.yml        ← orquestração dos 2 serviços
├── Dockerfile.hermes         ← build do hermes-gateway
├── restart.sh                ← script de reinicialização
├── config/
│   ├── config.yaml           ← configuração do Hermes Agent
│   └── .env                  ← variáveis de ambiente (não commitar!)
├── scripts/
│   └── entrypoint.sh         ← startup do container hermes
├── patches/                  ← patches uncensored (opcional)
├── logs/                     ← logs dos serviços (auto-criado)
├── models/                   ← modelos locais (opcional)
└── cache/                    ← cache HF/vLLM (auto-criado)
```

---

## Instalação

### 1. Configurar variáveis

Edite `config/.env`:

```env
VLLM_MODEL=facebook/opt-1.3b
VLLM_GPU_UTIL=0.9
VLLM_MAX_LEN=2048
VLLM_TP_SIZE=1
VLLM_API_KEY=hermes-local-secret-key

# Obrigatório se usar modelo gated (Llama etc.)
HF_TOKEN=hf_SEU_TOKEN_AQUI

# Telegram (opcional)
TELEGRAM_BOT_TOKEN=123456789:ABCdef...
TELEGRAM_WEBHOOK_URL=https://seu-dominio.ngrok-free.app/telegram
TELEGRAM_WEBHOOK_SECRET=gere-com-openssl-rand-hex-32

TZ=America/Sao_Paulo
```

### 2. Subir a stack

Abra o terminal WSL e execute:

```bash
cd /mnt/c/Users/User/Downloads/hermes/hermes-uncensored
docker compose up -d --build
```

Primeira vez demora ~5-10 min (download do modelo + build da imagem).

---

## Instalar e subir a UI (WebUI nativa)

A UI é uma aplicação Vue.js que builda na primeira vez. Pode levar 2-5 minutos.

```bash
cd /mnt/c/Users/User/Downloads/hermes/hermes-uncensored
docker compose up -d --build ui
```

Depois acesse: **http://localhost:3000**

Para recriar só a UI sem derrubar o resto:
```bash
docker compose up -d --build ui
```

Para ver os logs da build:
```bash
docker compose logs -f ui
```

```bash
cd /mnt/c/Users/User/Downloads/hermes/hermes-uncensored

# Só reinicia o hermes-gateway (mais rápido, vLLM continua rodando):
bash restart.sh

# Para tudo e sobe do zero (necessário após mudança no compose):
bash restart.sh full
```

---

## Links de acesso

| Serviço | URL | Descrição | Status |
|---|---|---|---|
| **Hermes WebUI** | http://localhost:3000 | Interface web nativa do Hermes Agent | 🔨 Em build... |
| **Hermes API** | http://localhost:8642 | API Gateway (OpenAI-compatible + Hermes extras) | ✅ Pronto |
| **vLLM API** | http://localhost:8000/v1 | LLM inference (modelos, completions, chat) | ✅ Pronto |
| **Modelos vLLM** | http://localhost:8000/v1/models | Lista dos modelos carregados | ✅ Pronto |

---

## Comandos úteis

```bash
# Ver status dos containers
docker compose ps

# Logs em tempo real do Hermes Gateway
docker compose logs -f hermes

# Logs em tempo real do vLLM
docker compose logs -f vllm

# Testar se vLLM responde
curl -s -H "Authorization: Bearer hermes-local-secret-key" \
  http://localhost:8000/v1/models | python3 -m json.tool

# Testar chat no Hermes API
curl -s -H "Authorization: Bearer hermes-local-secret-key" \
  http://localhost:8642/v1/models | python3 -m json.tool

# POST de conversa via Hermes
curl -X POST http://localhost:8642/chat \
  -H "Authorization: Bearer hermes-local-secret-key" \
  -H "Content-Type: application/json" \
  -d '{"message":"Olá! Quem é você?"}'
```

---

## Troubleshooting

### `api_server` (porta 8642) não responde
**Causa:** Plataforma `api_server` não está habilitada no `config.yaml`.  
**Solução:** Verifique que `config/config.yaml` tem:
```yaml
platforms:
  api_server:
    enabled: true
    host: 0.0.0.0
    port: 8642
```
E que o container tem `API_SERVER_KEY` set: `docker compose config | grep API_SERVER_KEY`.

---

## Sequência de startup

```
1. hermes-vllm inicia  →  carrega facebook/opt-1.3b na GPU  (~2-3 min)
2. healthcheck passa   →  curl /v1/models retorna 200
3. hermes-gateway inicia  →  aguarda vLLM responder (até 270s)
4. gateway.run inicia  →  WebUI disponível em :8081, API em :5000
```

---

## Segurança

> ⚠️ Este setup é para uso **local/desenvolvimento**. Para produção:

- Use **Docker Secrets** em vez de `.env`
- Substitua o `VLLM_API_KEY` por chave gerada: `openssl rand -hex 32`
- Gere o `TELEGRAM_WEBHOOK_SECRET`: `openssl rand -hex 32`
- Não exponha `:8000` (vLLM) para a internet
- Adicione `HF_TOKEN` real para modelos gated

---

## Trocar o modelo LLM

Edite `config/.env`:

```env
VLLM_MODEL=meta-llama/Meta-Llama-3.1-8B-Instruct
VLLM_MAX_LEN=32768
HF_TOKEN=hf_SEU_TOKEN_AQUI   # necessário para modelos Llama
```

Atualize `config/config.yaml` — troque `facebook/opt-1.3b` pelo novo modelo em todas as ocorrências:

```bash
sed -i 's|facebook/opt-1.3b|meta-llama/Meta-Llama-3.1-8B-Instruct|g' config/config.yaml
```

Reinicie tudo:
```bash
bash restart.sh full
```
