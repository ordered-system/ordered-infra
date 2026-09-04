# ordered-infra

The glue that runs [ordered-system](https://github.com/ordered-system) as one platform: local dev infrastructure, the full production stack, and the reverse proxy in front of it. If you only clone one repo from this org to see the whole system running, clone this one — then read [docs/GETTING_STARTED.md](docs/GETTING_STARTED.md).

## What's here

| File | Purpose |
|---|---|
| `docker-compose.yml` | **Local dev infra only** — Kafka (KRaft mode) + Kafka UI, Prometheus, Grafana (auto-provisioned dashboard), Jaeger. You run each service's own `./mvnw spring-boot:run` on the host against this. |
| `docker-compose.prod.yml` | **The entire platform, containerized** — every service, all datastores (3× Postgres, MongoDB, Redis), Kafka, the full observability stack, and Caddy as a reverse proxy with automatic HTTPS. This is what's deployed. |
| `Caddyfile` | Routes `your-domain` → gateway, `grafana.your-domain` → Grafana, `jaeger.your-domain` → Jaeger UI. Caddy handles TLS certificates automatically. |
| `prometheus/`, `grafana/provisioning/` | Scrape config and an auto-provisioned Grafana dashboard (`ordered-system-overview.json`) wired to every service's `/actuator/prometheus` endpoint. |
| `.env.prod.example` | Every secret and config value `docker-compose.prod.yml` needs, with **no defaults on purpose** — production should fail loudly on startup if a secret was forgotten, unlike local dev where everything has a `change-me` fallback. |

## Repository layout this expects

`docker-compose.prod.yml` builds each service straight from source using relative build contexts, so every repo needs to be cloned as a **sibling directory**:

```
workspace/
├── ordered-infra/              ← you run docker compose from here
├── ordered-eureka/
├── ordered-gateway/
├── ordered-config-server/
├── ordered-commons/             (built as an additional context for the 4 services below)
├── ordered-order-service/
├── ordered-product-service/
├── ordered-user-service/
└── ordered-engagement-service/
```

See [docs/GETTING_STARTED.md](docs/GETTING_STARTED.md) for the clone commands.

## Quick start (local dev infra)

```bash
make up      # Kafka + Kafka UI + Prometheus + Grafana + Jaeger
```

Then run each business service yourself with `./mvnw spring-boot:run` in its own repo. Full walkthrough: [docs/GETTING_STARTED.md](docs/GETTING_STARTED.md).

## Production stack

```bash
cp .env.prod.example .env.prod    # fill in real secrets
make prod-up                      # builds and starts everything, including Caddy
```

Full walkthrough, including the Oracle Cloud Always Free ARM VM this was actually deployed to: [docs/DEPLOY.md](docs/DEPLOY.md).

## Docs

- **[docs/GETTING_STARTED.md](docs/GETTING_STARTED.md)** — clone everything, run it locally, hit the API.
- **[docs/DEPLOY.md](docs/DEPLOY.md)** — take it from `docker-compose.prod.yml` on your laptop to a live domain on a VM.
- **[docs/TESTING.md](docs/TESTING.md)** — how each repo's tests work, and how to run the Gatling load tests against a running stack.
- **[docs/ARCHITECTURE.md](docs/ARCHITECTURE.md)** — the system as a whole: services, data ownership, event flow, why things are shaped the way they are.

## Where this fits

Part of the [ordered-system](https://github.com/ordered-system) organization. Every other repo is a piece this one assembles — see the [org profile](https://github.com/ordered-system) for the full map.

## License

MIT — see [LICENSE](LICENSE).
