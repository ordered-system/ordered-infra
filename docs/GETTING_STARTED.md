# Getting started — running ordered-system locally

This walks through cloning every repo and running the **whole platform on your machine**, with each Java service running directly via Maven (not containerized) against containerized infrastructure. This is the fastest inner loop for actually developing on the system. If you just want to see it deployed without building it yourself, there's nothing to see yet — it isn't a public demo instance.

For running everything containerized instead (closer to production), see [DEPLOY.md](DEPLOY.md) — the same `docker-compose.prod.yml` works fine on a laptop, just point `BASE_DOMAIN` at `localhost` or an IP.

## Prerequisites

- Java 21 (Temurin recommended)
- Maven (or use each repo's `./mvnw` wrapper — no separate install needed)
- Docker + Docker Compose
- ~4 GB RAM free for containers (3× Postgres, MongoDB, Redis, Kafka, Prometheus, Grafana, Jaeger)

## 1. Clone everything as siblings

```bash
mkdir ordered-system && cd ordered-system

for repo in ordered-infra ordered-eureka ordered-gateway ordered-config-server \
            ordered-commons ordered-order-service ordered-product-service \
            ordered-user-service ordered-engagement-service; do
  git clone https://github.com/ordered-system/$repo.git
done
```

## 2. Build ordered-commons once

It isn't published anywhere — every service that depends on it needs it in your local `~/.m2` first.

```bash
cd ordered-commons && make install && cd ..
```

## 3. Start local dev infrastructure

```bash
cd ordered-infra
make up
```

Starts, on the host:

| Service | URL |
|---|---|
| Kafka (broker) | `localhost:29092` |
| Kafka UI | http://localhost:8090 |
| Prometheus | http://localhost:9090 |
| Grafana | http://localhost:3000 (admin/admin, or browse anonymously) |
| Jaeger UI | http://localhost:16686 |

This does **not** start Postgres/Mongo/Redis or any of the Java services — each business service brings up its own datastore via its own `docker-compose.yml` (see next step), and you run the Java processes yourself.

## 4. Start each service, in order

Order matters: eureka and the config server first, then the gateway, then the four business services (any order among themselves).

```bash
# terminal 1
cd ordered-eureka && ./mvnw spring-boot:run

# terminal 2 — needs a JWT secret; use anything for local dev
cd ordered-config-server && JWT_SECRET=local-dev-secret-please-change ./mvnw spring-boot:run

# terminal 3
cd ordered-gateway && ./mvnw spring-boot:run

# terminal 4
cd ordered-order-service && make up && STRIPE_SECRET_KEY=sk_test_... make run

# terminal 5
cd ordered-product-service && make up && make run

# terminal 6
cd ordered-user-service && make up && make run

# terminal 7
cd ordered-engagement-service && make up && make run
```

Each service's own `make up` starts just its own datastore container (Postgres on a distinct host port per service, or MongoDB for engagement-service) — separate from the shared infra started in step 3.

Don't have a real Stripe test key handy? `order-service` will still start with the `sk_test_placeholder` default — payment calls will just fail, which is fine if you're not exercising the checkout flow.

## 5. Confirm it's up

- Eureka dashboard (all 5 services should show `UP`): http://localhost:8761
- Gateway Swagger UI (aggregated docs for every service): http://localhost:8080/swagger-ui.html
- Try the real flow through the gateway:

```bash
curl -X POST http://localhost:8080/api/v1/auth/register \
  -H "Content-Type: application/json" \
  -d '{"email":"test@example.com","password":"password123","firstName":"Test","lastName":"User"}'
```

## Ports at a glance

| Service | Port |
|---|---|
| ordered-eureka | 8761 |
| ordered-config-server | 8888 |
| ordered-gateway | 8080 |
| ordered-order-service | 9091 |
| ordered-product-service | 9092 |
| ordered-user-service | 9093 |
| ordered-engagement-service | 9094 |
| Kafka (host) | 29092 |
| Kafka UI | 8090 |
| Prometheus | 9090 |
| Grafana | 3000 |
| Jaeger UI | 16686 |

## Next

- Run the real load tests against this stack: [ordered-load-tests](https://github.com/ordered-system/ordered-load-tests) and [TESTING.md](TESTING.md).
- Understand why it's shaped this way: [ARCHITECTURE.md](ARCHITECTURE.md).
- Take it to a real domain on a VM: [DEPLOY.md](DEPLOY.md).
