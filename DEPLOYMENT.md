# Deployment Guide

This guide covers deploying Letta with the letta-skill infrastructure management system. It includes options for self-hosted deployments, cloud deployments, and various configuration scenarios.

## Table of Contents

- [Prerequisites](#prerequisites)
- [Quick Start](#quick-start)
- [Self-Hosted Deployment](#self-hosted-deployment)
  - [Docker Deployment](#docker-deployment)
  - [Docker Compose Deployment](#docker-compose-deployment)
  - [Manual Deployment](#manual-deployment)
- [Cloud Deployment](#cloud-deployment)
- [Configuration](#configuration)
- [LLM Provider Setup](#llm-provider-setup)
- [PostgreSQL Setup](#postgresql-setup)
- [Health Checks](#health-checks)
- [Troubleshooting](#troubleshooting)
- [Production Considerations](#production-considerations)

## Prerequisites

### Required

- **Docker**: Version 20.10 or higher
- **Docker Compose**: Version 2.0 or higher
- **Bash shell**: For running helper scripts
- **curl**: For API requests
- **jq**: For JSON parsing (optional but recommended)

### Optional

- **PostgreSQL client tools**: For direct database access
- **psql**: For PostgreSQL command-line access
- **Git**: For cloning repositories

## Quick Start

### 1. Clone the Repository

```bash
git clone https://github.com/your-username/letta-skill.git
cd letta-skill
```

### 2. Configure Environment

```bash
# Copy the example environment file
cp .env.example .env

# Edit .env with your actual values
nano .env
```

Required variables:
```bash
LETTA_BASE_URL=http://localhost:8283
LETTA_API_KEY=${LETTA_API_KEY}
```

### 3. Start Letta Server

```bash
# Using Docker
docker run -d \
  --name letta-server \
  -v ~/.letta/.persist/pgdata:/var/lib/postgresql/data \
  -p 8283:8283 \
  -e LETTA_POSTGRES_URI=postgresql://${POSTGRES_USER:-letta}:${POSTGRES_PASSWORD}@host.docker.internal:5432/${POSTGRES_DB:-letta} \
  -e OPENROUTER_API_KEY=${OPENROUTER_API_KEY} \
  letta/letta:latest
```

### 4. Verify Deployment

```bash
# Check server health
curl -s http://localhost:8283/v1/health | jq .

# Run health check script
source scripts/letta_secrets.sh
letta_secrets_validate_all
```

## Self-Hosted Deployment

### Docker Deployment

Docker is the recommended method for self-hosting Letta. It provides isolation and reproducibility.

#### Basic Docker Run

```bash
docker run -d \
  --name letta-server \
  -v ~/.letta/.persist/pgdata:/var/lib/postgresql/data \
  -p 8283:8283 \
  -e LETTA_POSTGRES_URI=postgresql://${POSTGRES_USER:-letta}:${POSTGRES_PASSWORD}@host.docker.internal:5432/${POSTGRES_DB:-letta} \
  -e OPENROUTER_API_KEY=${OPENROUTER_API_KEY} \
  letta/letta:latest
```

#### Docker Run with All Providers

```bash
docker run -d \
  --name letta-server \
  -v ~/.letta/.persist/pgdata:/var/lib/postgresql/data \
  -p 8283:8283 \
  -e LETTA_POSTGRES_URI=postgresql://${POSTGRES_USER:-letta}:${POSTGRES_PASSWORD}@host.docker.internal:5432/${POSTGRES_DB:-letta} \
  -e OPENROUTER_API_KEY=${OPENROUTER_API_KEY} \
  -e OPENAI_API_KEY=${OPENAI_API_KEY} \
  -e ANTHROPIC_API_KEY=${ANTHROPIC_API_KEY} \
  -e OLLAMA_BASE_URL=http://host.docker.internal:11434 \
  letta/letta:latest
```

#### Docker Run with Custom Model

```bash
docker run -d \
  --name letta-server \
  -v ~/.letta/.persist/pgdata:/var/lib/postgresql/data \
  -p 8283:8283 \
  -e LETTA_POSTGRES_URI=postgresql://${POSTGRES_USER:-letta}:${POSTGRES_PASSWORD}@host.docker.internal:5432/${POSTGRES_DB:-letta} \
  -e OPENROUTER_API_KEY=${OPENROUTER_API_KEY} \
  -e LETTA_MODEL=OpenRouter/z-ai/glm-4.5-air:free \
  letta/letta:latest
```

### Docker Compose Deployment

Docker Compose is recommended for multi-container deployments with PostgreSQL.

#### Create docker-compose.yml

```yaml
version: '3.8'

services:
  postgres:
    image: postgres:15
    container_name: letta-postgres
    environment:
      POSTGRES_USER: letta
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD}
      POSTGRES_DB: letta
    volumes:
      - pgdata:/var/lib/postgresql/data
    ports:
      - "5432:5432"
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U letta"]
      interval: 10s
      timeout: 5s
      retries: 5

  letta:
    image: letta/letta:latest
    container_name: letta-server
    ports:
      - "8283:8283"
    environment:
      LETTA_POSTGRES_URI: postgresql://${POSTGRES_USER:-letta}:${POSTGRES_PASSWORD}@postgres:5432/${POSTGRES_DB:-letta}
      OPENROUTER_API_KEY: ${OPENROUTER_API_KEY}
      OPENAI_API_KEY: ${OPENAI_API_KEY}
      ANTHROPIC_API_KEY: ${ANTHROPIC_API_KEY}
    depends_on:
      postgres:
        condition: service_healthy
    volumes:
      - ~/.letta/.persist:/app/.persist
    restart: unless-stopped

volumes:
  pgdata:
```

#### Start with Docker Compose

```bash
# Start all services
docker-compose up -d

# View logs
docker-compose logs -f

# Stop all services
docker-compose down

# Stop and remove volumes
docker-compose down -v
```

### Manual Deployment

For advanced users who prefer manual setup without Docker.

#### Prerequisites

- Python 3.10 or higher
- PostgreSQL 15 or higher with pgvector extension
- Letta Python package

#### Install Letta

```bash
# Install via pip
pip install letta

# Or install from source
git clone https://github.com/letta-ai/letta.git
cd letta
pip install -e .
```

#### Setup PostgreSQL

```bash
# Create database
createdb letta

# Enable pgvector extension
psql -d letta -c "CREATE EXTENSION IF NOT EXISTS vector;"
```

#### Configure Environment

```bash
export LETTA_POSTGRES_URI=postgresql://${POSTGRES_USER:-letta}:${POSTGRES_PASSWORD}@localhost:5432/${POSTGRES_DB:-letta}
export OPENROUTER_API_KEY=${OPENROUTER_API_KEY}
export OPENAI_API_KEY=${OPENAI_API_KEY}
export ANTHROPIC_API_KEY=${ANTHROPIC_API_KEY}
```

#### Start Letta Server

```bash
letta server
```

## Cloud Deployment

### Letta Cloud

The easiest option is to use Letta's managed cloud service.

1. Sign up at [app.letta.com](https://app.letta.com)
2. Get your API key from the dashboard
3. Configure your skill:

```bash
LETTA_BASE_URL=https://api.letta.com
LETTA_API_KEY=${LETTA_API_KEY}
```

### Cloud Providers

#### AWS Deployment

```yaml
# docker-compose.aws.yml
version: '3.8'

services:
  postgres:
    image: postgres:15
    environment:
      POSTGRES_USER: letta
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD}
      POSTGRES_DB: letta
    volumes:
      - postgres-data:/var/lib/postgresql/data

  letta:
    image: letta/letta:latest
    ports:
      - "8283:8283"
    environment:
      LETTA_POSTGRES_URI: postgresql://letta:${POSTGRES_PASSWORD}@postgres:5432/letta
      OPENROUTER_API_KEY: ${OPENROUTER_API_KEY}
    depends_on:
      - postgres

volumes:
  postgres-data:
```

Deploy with ECS or EKS following AWS documentation.

#### Google Cloud Deployment

```yaml
# docker-compose.gcp.yml
version: '3.8'

services:
  postgres:
    image: postgres:15
    environment:
      POSTGRES_USER: letta
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD}
      POSTGRES_DB: letta
    volumes:
      - postgres-data:/var/lib/postgresql/data

  letta:
    image: letta/letta:latest
    ports:
      - "8283:8283"
    environment:
      LETTA_POSTGRES_URI: postgresql://letta:${POSTGRES_PASSWORD}@postgres:5432/letta
      OPENROUTER_API_KEY: ${OPENROUTER_API_KEY}
    depends_on:
      - postgres

volumes:
  postgres-data:
```

Deploy with Cloud Run or GKE following GCP documentation.

#### Azure Deployment

```yaml
# docker-compose.azure.yml
version: '3.8'

services:
  postgres:
    image: postgres:15
    environment:
      POSTGRES_USER: letta
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD}
      POSTGRES_DB: letta
    volumes:
      - postgres-data:/var/lib/postgresql/data

  letta:
    image: letta/letta:latest
    ports:
      - "8283:8283"
    environment:
      LETTA_POSTGRES_URI: postgresql://letta:${POSTGRES_PASSWORD}@postgres:5432/letta
      OPENROUTER_API_KEY: ${OPENROUTER_API_KEY}
    depends_on:
      - postgres

volumes:
  postgres-data:
```

Deploy with Container Instances or AKS following Azure documentation.

## Configuration

### Environment Variables

Reference `.env.example` for all available variables.

#### Required Variables

- `LETTA_BASE_URL`: URL of your Letta server
- `LETTA_API_KEY`: Your Letta API key

#### Optional Variables

- `LETTA_MODEL`: Default model for agent creation
- `LETTA_POSTGRES_URI`: PostgreSQL connection string
- `OPENROUTER_API_KEY`: OpenRouter API key
- `OPENAI_API_KEY`: OpenAI API key
- `ANTHROPIC_API_KEY`: Anthropic API key
- `OLLAMA_BASE_URL`: Ollama server URL
- `VLLM_API_BASE`: vLLM server URL
- `LETTA_CONTAINER_NAME`: Docker container name for health checks

### Configuration File

Letta supports configuration via `conf.yaml`:

```yaml
llm:
  model: "OpenRouter/z-ai/glm-4.5-air:free"
  temperature: 0.7
  max_tokens: 2000

memory:
  context_window: 128000
  embedding_model: "text-embedding-3-small"

database:
  uri: "postgresql://${POSTGRES_USER:-letta}:${POSTGRES_PASSWORD}@localhost:5432/${POSTGRES_DB:-letta}"
```

## LLM Provider Setup

### OpenRouter

1. Sign up at [openrouter.ai](https://openrouter.ai)
2. Get your API key
3. Configure:

```bash
export OPENROUTER_API_KEY=${OPENROUTER_API_KEY}
export LETTA_MODEL=OpenRouter/z-ai/glm-4.5-air:free
```

### OpenAI

1. Sign up at [openai.com](https://openai.com)
2. Get your API key
3. Configure:

```bash
export OPENAI_API_KEY=${OPENAI_API_KEY}
export LETTA_MODEL=openai/gpt-4
```

### Anthropic

1. Sign up at [anthropic.com](https://anthropic.com)
2. Get your API key
3. Configure:

```bash
export ANTHROPIC_API_KEY=${ANTHROPIC_API_KEY}
export LETTA_MODEL=anthropic/claude-3-opus
```

### Ollama

1. Install Ollama: [ollama.ai](https://ollama.ai)
2. Pull a model:

```bash
ollama pull llama2
```

3. Configure:

```bash
export OLLAMA_BASE_URL=http://localhost:11434
export LETTA_MODEL=ollama/llama2
```

### vLLM

1. Install vLLM
2. Start vLLM server

```bash
python -m vllm.entrypoints.openai.api_server --model meta-llama/Llama-2-7b-chat-hf
```

3. Configure:

```bash
export VLLM_API_BASE=http://localhost:8000
export LETTA_MODEL=vllm/meta-llama/Llama-2-7b-chat-hf
```

## PostgreSQL Setup

### Local PostgreSQL

#### Install PostgreSQL

```bash
# Ubuntu/Debian
sudo apt-get install postgresql postgresql-contrib

# macOS
brew install postgresql

# Windows
# Download from postgresql.org
```

#### Create Database and User

```bash
# Switch to postgres user
sudo -u postgres psql

# In PostgreSQL prompt
CREATE USER ${POSTGRES_USER:-letta} WITH PASSWORD '${POSTGRES_PASSWORD}';
CREATE DATABASE letta OWNER letta;
\c letta
CREATE EXTENSION IF NOT EXISTS vector;
\q
```

### Docker PostgreSQL

```bash
docker run -d \
  --name letta-postgres \
  -e POSTGRES_USER=letta \
  -e POSTGRES_PASSWORD=${POSTGRES_PASSWORD} \
  -e POSTGRES_DB=letta \
  -v pgdata:/var/lib/postgresql/data \
  -p 5432:5432 \
  postgres:15
```

### Verify pgvector Extension

```bash
# From host
psql postgresql://${POSTGRES_USER:-letta}:${POSTGRES_PASSWORD}@localhost:5432/${POSTGRES_DB:-letta} -c "SELECT extname FROM pg_extension WHERE extname = 'vector';"

# From container
docker exec -it letta-postgres psql -U letta -d letta -c "SELECT extname FROM pg_extension WHERE extname = 'vector';"
```

## Health Checks

### Server Health

```bash
curl -s http://localhost:8283/v1/health | jq .
```

### Database Connectivity

```bash
# Through Letta API
curl -s "http://localhost:8283/v1/agents?limit=1" \
  -H "Authorization: Bearer $LETTA_API_KEY" | jq .

# Direct PostgreSQL
psql postgresql://${POSTGRES_USER:-letta}:${POSTGRES_PASSWORD}@localhost:5432/${POSTGRES_DB:-letta} -c "SELECT version();"
```

### LLM Provider Health

```bash
# OpenRouter
curl -s https://openrouter.ai/api/v1/auth/key \
  -H "Authorization: Bearer $OPENROUTER_API_KEY" | jq .

# OpenAI
curl -s https://api.openai.com/v1/models \
  -H "Authorization: Bearer $OPENAI_API_KEY" | jq .
```

### Comprehensive Health Check

```bash
source scripts/letta_secrets.sh
letta_secrets_validate_all
```

## Troubleshooting

### Container Won't Start

```bash
# Check logs
docker logs letta-server

# Common issues:
# - PostgreSQL connection failure: Check LETTA_POSTGRES_URI
# - Missing API keys: Verify LLM provider keys
# - Port conflict: Change port mapping
```

### PostgreSQL Connection Refused

```bash
# Check PostgreSQL is running
docker ps | grep postgres

# Test connection
psql postgresql://${POSTGRES_USER:-letta}:${POSTGRES_PASSWORD}@localhost:5432/${POSTGRES_DB:-letta} -c "SELECT 1;"

# For Docker networking, use host.docker.internal
docker exec -it letta-server psql postgresql://${POSTGRES_USER:-letta}:${POSTGRES_PASSWORD}@host.docker.internal:5432/${POSTGRES_DB:-letta} -c "SELECT 1;"
```

### Missing pgvector Extension

```bash
# Enable extension
psql postgresql://${POSTGRES_USER:-letta}:${POSTGRES_PASSWORD}@localhost:5432/${POSTGRES_DB:-letta} -c "CREATE EXTENSION IF NOT EXISTS vector;"

# Verify
psql postgresql://${POSTGRES_USER:-letta}:${POSTGRES_PASSWORD}@localhost:5432/${POSTGRES_DB:-letta} -c "SELECT extname FROM pg_extension WHERE extname = 'vector';"
```

### API Key Authentication Failed

```bash
# Verify API key format
echo $LETTA_API_KEY

# Test with curl
curl -s http://localhost:8283/v1/ \
  -H "Authorization: Bearer $LETTA_API_KEY" | jq .
```

### Agent Creation Failed

```bash
# Verify model format
# OpenRouter: OpenRouter/provider/model:free
# OpenAI: openai/gpt-4
# Anthropic: anthropic/claude-3-opus

# Check memory blocks are included
curl -s -X POST http://localhost:8283/v1/agents/ \
  -H "Authorization: Bearer $LETTA_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "test-agent",
    "model": "OpenRouter/z-ai/glm-4.5-air:free",
    "memory_blocks": [
      {"label": "persona", "value": "Test persona", "limit": 2000},
      {"label": "human", "value": "Test human", "limit": 2000}
    ]
  }' | jq .
```

## Production Considerations

### Security

- Use strong passwords for PostgreSQL
- Enable SSL/TLS for database connections
- Rotate API keys regularly
- Use environment-specific configurations
- Implement proper secret management (AWS Secrets Manager, HashiCorp Vault)
- Restrict network access with firewalls
- Use HTTPS for all API communications

### Scaling

- Use load balancers for multiple Letta instances
- Implement database connection pooling
- Consider read replicas for PostgreSQL
- Monitor resource usage (CPU, memory, disk)
- Implement auto-scaling based on load

### Monitoring

- Monitor Letta server logs: `docker logs -f letta-server`
- Track agent creation and deletion rates
- Monitor PostgreSQL performance
- Set up alerts for API failures
- Track LLM provider API usage and costs
- Monitor memory block sizes and archival memory growth

### Backup

- Regular PostgreSQL backups
```bash
docker exec letta-postgres pg_dump -U letta letta > backup.sql
```

- Backup agent configurations via API
- Document environment configurations
- Version control your .env.example file

### High Availability

- Deploy multiple Letta instances behind a load balancer
- Use PostgreSQL streaming replication
- Implement failover mechanisms
- Test disaster recovery procedures

### Performance Optimization

- Tune PostgreSQL configuration for your workload
- Use appropriate model sizes for your use case
- Implement caching where appropriate
- Optimize memory block sizes
- Monitor and optimize archival memory queries

## Additional Resources

- [Letta Documentation](https://docs.letta.com)
- [Letta GitHub Repository](https://github.com/letta-ai/letta)
- [Letta Discord](https://discord.gg/letta)
- [Letta Forum](https://forum.letta.com)
- [Docker Documentation](https://docs.docker.com)
- [PostgreSQL Documentation](https://www.postgresql.org/docs)
