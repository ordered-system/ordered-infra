# Architecture

`ordered-system` is an Allegro-inspired e-commerce marketplace, built as a portfolio project to practice distributed-systems patterns that a monolith doesn't teach: inter-service communication, event propagation, distributed observability, and multi-service deployment. It started life as a single Spring Boot application — [`ordered-backend`](https://github.com/ordered-system/ordered-backend) — and was decomposed into four independent services using the **Strangler Fig** pattern.

## The services

```
                              Internet
                                 │
                          ┌──────▼──────┐
                          │ ordered-    │
                          │ gateway     │  JWT verification at the edge,
                          │  :8080      │  routing, Swagger aggregation
                          └──────┬──────┘
                                 │ lb://... (via Eureka)
        ┌───────────┬───────────┼───────────┬───────────┐
        │           │           │           │
   ┌────▼────┐ ┌────▼─────┐┌────▼─────┐┌────▼──────────┐
   │  order  │ │ product  ││   user   ││  engagement    │
   │ service │ │ service  ││ service  ││   service      │
   │  :9091  │ │  :9092   ││  :9093   ││    :9094       │
   └────┬────┘ └────┬─────┘└────┬─────┘└────┬───────────┘
        │           │           │           │
   PostgreSQL   PostgreSQL  PostgreSQL   MongoDB
   (order_db)   + Redis     (user_db)   (engagement_db)
                (product_db)

   ordered-eureka (:8761) ── service discovery, all services register here
   ordered-config-server (:8888) ── central JWT secret, native profile
   ordered-commons ── shared library: JWT claims filter, exception handling, PageResponse
```

Each business service owns its database exclusively — no service reaches into another's schema. All cross-service communication is either a synchronous REST call (used sparingly — see below) or an asynchronous Kafka event.

| Service | Owns | Responsible for |
|---|---|---|
| [ordered-order-service](https://github.com/ordered-system/ordered-order-service) | PostgreSQL | Orders, checkout orchestration, payments (Stripe + Resilience4j) |
| [ordered-product-service](https://github.com/ordered-system/ordered-product-service) | PostgreSQL + Redis | Catalog, cart, stock/checkout reservations |
| [ordered-user-service](https://github.com/ordered-system/ordered-user-service) | PostgreSQL | Users, auth, JWT issuance, address book |
| [ordered-engagement-service](https://github.com/ordered-system/ordered-engagement-service) | MongoDB | Reviews (verified-purchase only), browsing history |

## Authentication: stateless JWT, verified once

`user-service` is the only service that issues a JWT (HS256, custom claims: `userId`, `roles`). `ordered-gateway` verifies the signature **once**, at the edge, using a secret both it and `user-service` read from `ordered-config-server` — so downstream services never re-verify a signature, they just trust the claims and parse them via `ordered-commons`' `JwtClaimsAuthenticationFilter`. This keeps auth logic in exactly two places (issue, verify) instead of duplicated across five services.

## Inter-service communication

**Synchronous (REST)** — used only where a request genuinely can't proceed without an immediate answer: `order-service` calls `product-service` to reserve stock during checkout, wrapped in a Resilience4j circuit breaker + retry so a slow/unavailable `product-service` degrades gracefully instead of hanging the whole checkout.

**Asynchronous (Kafka, transactional outbox)** — used for everything that's a fact about something that already happened, which other services need to react to eventually rather than immediately:

- `order-service` publishes `order-delivered` when an order transitions to delivered → `engagement-service` consumes it to unlock reviews.
- `product-service` publishes/consumes `order-cancelled` → releases a stock reservation.

The **outbox pattern** is what makes this reliable without a distributed transaction: a state change and its corresponding event row are written to the database in the *same* local transaction, then a scheduled poller publishes the event to Kafka afterward. If the poller crashes mid-publish, the event is still in the table and gets picked up on the next poll — at-least-once delivery, which is why every consumer also tracks `ProcessedEvent` IDs to stay idempotent against redelivery.

## Observability

Every service exports the same three signals, scraped/collected centrally:

- **Metrics** — Micrometer → Prometheus → Grafana, with a shared auto-provisioned dashboard (`ordered-system-overview`).
- **Traces** — OpenTelemetry → Jaeger, sampled at 100% (this is a demo system, not production-scale traffic, so full sampling is cheap and useful).
- **Logs** — structured, per-container, viewable via `docker compose logs` / `make prod-logs`.

This is what makes a latency regression across services actually debuggable instead of a guessing game — a slow request in Jaeger shows exactly which service and which downstream call ate the time.

## Why decompose at all?

The monolith ([`ordered-backend`](https://github.com/ordered-system/ordered-backend)) was a fully functional standalone system on its own — catalog, cart, orders, payments, reviews, JWT auth, full observability stack, all in one process. It had fulfilled its educational purpose: proving out Kafka + the outbox pattern, eventual consistency, and a mixed relational/NoSQL/cache datastore setup, all from scratch. The natural next step was **decomposing** it, since a monolith inherently can't teach service discovery, distributed config, inter-service failure handling, or coordinating a multi-service deployment — which is exactly what this decomposition, `ordered-eureka`, `ordered-gateway`, `ordered-config-server`, and `ordered-infra` exist to practice.

## Related docs

- [GETTING_STARTED.md](GETTING_STARTED.md) — run it yourself.
- [DEPLOY.md](DEPLOY.md) — take it to a live VM.
- [TESTING.md](TESTING.md) — unit/integration/load testing conventions.
