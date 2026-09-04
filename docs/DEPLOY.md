# Deploying ordered-system

How the full stack (`docker-compose.prod.yml`) goes from source to a live domain with HTTPS. This system runs on an **Oracle Cloud Always Free ARM VM** (4 OCPUs / 24 GB RAM on the Ampere A1 shape, at no cost), but nothing here is Oracle-specific — any VM with Docker and a public IP works.

## What gets deployed

Everything, containerized, on one VM: `ordered-eureka`, `ordered-config-server`, `ordered-gateway`, all four business services, 3× Postgres, MongoDB, Redis, Kafka, Prometheus, Grafana, Jaeger, and **Caddy** in front of all of it as a reverse proxy with automatic HTTPS (Caddy requests and renews Let's Encrypt certificates on its own — no certbot, no manual cert management).

```
Internet ──HTTPS──▶ Caddy ──▶ gateway:8080 ──▶ [order|product|user|engagement]-service
                       │
                       ├──▶ grafana.<domain> ──▶ grafana:3000
                       └──▶ jaeger.<domain>  ──▶ jaeger:16686
```

## 1. Provision a VM

Any Docker-capable host with a public IPv4 works. For the Oracle Cloud Always Free path specifically:

1. Create an Ampere A1 (ARM) instance — the free tier gives up to 4 OCPUs / 24 GB RAM, which comfortably runs this whole stack.
2. Open ports **80** and **443** in the VM's security list / network security group (Caddy needs both — 80 for the ACME HTTP challenge, 443 for actual traffic).
3. Install Docker + the Compose plugin on the VM.
4. Since the images here are built from source rather than pulled, build on the VM itself (or build ARM64 images elsewhere and push them somewhere the VM can pull from) — the `Dockerfile`s use `eclipse-temurin` base images, which publish multi-arch (amd64/arm64) tags, so building directly on an ARM VM works without changes.

## 2. Point a domain at it

You need *some* hostname for Caddy to request a certificate for — a bare IP address can't get a Let's Encrypt cert. Two options:

- A real domain, with an `A` record pointing at the VM's public IP.
- No domain yet? [sslip.io](https://sslip.io) gives you one for free by encoding the IP in the hostname itself, e.g. `203.0.113.10.sslip.io` resolves to `203.0.113.10` — no DNS setup required, good enough for a portfolio deployment.

## 3. Clone every repo as a sibling, on the VM

Same layout as local dev — see [GETTING_STARTED.md](GETTING_STARTED.md#1-clone-everything-as-siblings):

```bash
mkdir ordered-system && cd ordered-system
for repo in ordered-infra ordered-eureka ordered-gateway ordered-config-server \
            ordered-commons ordered-order-service ordered-product-service \
            ordered-user-service ordered-engagement-service; do
  git clone https://github.com/ordered-system/$repo.git
done
```

## 4. Configure secrets

```bash
cd ordered-infra
cp .env.prod.example .env.prod
```

Fill in every value — `docker-compose.prod.yml` has **no fallback defaults** for these on purpose, so a forgotten secret fails the container at startup instead of silently running with a placeholder in production:

| Variable | How to generate |
|---|---|
| `BASE_DOMAIN` | Your real domain, or `<vm-ip>.sslip.io` |
| `JWT_SECRET` | `openssl rand -base64 48` |
| `STRIPE_SECRET_KEY` | A real Stripe key — `sk_test_...` unless you're genuinely ready to take live payments (`sk_live_...`) |
| `ORDER_DB_PASSWORD`, `PRODUCT_DB_PASSWORD`, `USER_DB_PASSWORD` | `openssl rand -base64 24` each, all different |
| `MONGO_ROOT_USERNAME` / `MONGO_ROOT_PASSWORD` | Your choice / `openssl rand -base64 24` |
| `GRAFANA_ADMIN_PASSWORD` | Your choice |

`.env.prod` is gitignored — never commit it.

## 5. Bring the stack up

```bash
make prod-up
```

This runs `docker compose -f docker-compose.prod.yml --env-file .env.prod up -d --build` — builds every service's image from source (using `ordered-commons` as an additional build context where needed) and starts everything, Caddy included.

First boot takes a few minutes: Postgres/Mongo need to initialize, then eureka + config-server need to be reachable before the gateway and business services register successfully. Caddy won't get a valid certificate until DNS for `BASE_DOMAIN` actually resolves to the VM.

## 6. Verify

```bash
make prod-ps                          # every container should be Up
make prod-logs                        # tail everything if something's stuck
curl -I https://<your-domain>/api/v1/products
```

- App: `https://<your-domain>`
- Grafana: `https://grafana.<your-domain>` (login: `admin` / your `GRAFANA_ADMIN_PASSWORD`)
- Jaeger: `https://jaeger.<your-domain>`

Run the smoke test from [ordered-load-tests](https://github.com/ordered-system/ordered-load-tests) against the live domain to confirm the full flow works end-to-end:

```bash
GATEWAY_URL=https://<your-domain> ./scripts/smoke-test-full-flow.sh
```

## Updating a single service

```bash
make prod-build SERVICE=order-service
```

Rebuilds just that service's image from its current source and restarts only that container — the rest of the stack keeps running.

## Tearing down

```bash
make prod-down
```

Stops every container but **keeps data volumes** (Postgres/Mongo/Grafana data survives). To wipe everything including data, add `-v` to the underlying `docker compose down` command manually — there's no Makefile shortcut for that on purpose, to avoid an accidental one-command data wipe.

## Notes / things worth knowing before you hit them

- **Anonymous Grafana access is disabled in prod** (`GF_AUTH_ANONYMOUS_ENABLED: "false"`), unlike local dev — you need the admin password to view dashboards.
- Because every service is built from source on first boot, `make prod-up` the very first time is noticeably slower than subsequent restarts (Docker layer caching helps after that).
- If a service can't reach `config-server` or `eureka` on first boot, check `depends_on` conditions in `docker-compose.prod.yml` — the `condition: service_healthy` waits are what keep the business services from starting before their databases are actually accepting connections.
