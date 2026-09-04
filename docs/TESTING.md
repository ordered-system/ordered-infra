# Testing ordered-system

Three layers, from fastest/narrowest to slowest/broadest: unit tests (per repo, no containers), integration tests (per repo, real Testcontainers), and load/smoke tests (whole system, [ordered-load-tests](https://github.com/ordered-system/ordered-load-tests)).

## Unit tests

Every business-logic repo (`ordered-commons`, `ordered-config-server`, `ordered-order-service`, `ordered-product-service`, `ordered-user-service`, `ordered-engagement-service`) uses the same Makefile convention:

```bash
cd ordered-order-service     # or any other service
make test-unit
```

No Docker required — pure JUnit, mocks for anything external. These run on every push in CI.

## Integration tests

```bash
make test-integration        # or just `make test` on services where it's the default target
```

Requires Docker — these spin up **real** Testcontainers (Postgres, Redis, MongoDB depending on the service), not mocks. The convention across every service:

- Containers are declared **inline** in the test class itself (`static @ServiceConnection PostgreSQLContainer<?> postgres = ...`) — there's no shared base test class, to keep each test file self-contained and easy to read top-to-bottom.
- Integration tests live in the **parent package** matching the bounded context (e.g. `pl.dybcio.ordered.payment.StripePaymentIntegrationTest`), while pure unit tests live in a nested `.service` subpackage (e.g. `pl.dybcio.ordered.payment.service.StripePaymentServiceTest`) — the package alone tells you which kind of test you're looking at.

Worth reading if you want to see the pattern:

| Repo | Good integration test to start with |
|---|---|
| ordered-order-service | `StripePaymentIntegrationTest` |
| ordered-product-service | `CheckoutFlowIntegrationTest` |
| ordered-user-service | `RegisterLoginFlowIntegrationTest` |
| ordered-engagement-service | `OrderDeliveredFlowIntegrationTest`, `ReviewFlowIntegrationTest` |

One gotcha, in case you hit it while modifying a service: `src/test/resources/application.yml` **fully replaces** — not merges with — `src/main/resources/application.yml` during tests. That's why every service's Maven Surefire/Failsafe config disables the config-server import for tests (`-Dspring.cloud.config.enabled=false`) — otherwise tests would try to reach a real config server that isn't running.

### CI

Every service's `.github/workflows/ci.yml` runs three jobs on every push — `lint` (Spotless format check), `unit-tests`, and `integration-tests` (main branch / PRs into main only, since it's the slowest job). All three first checkout and `mvn install` [`ordered-commons`](https://github.com/ordered-system/ordered-commons) from source, since it isn't published anywhere services could just pull it from.

## Load and smoke tests

Against a **running stack** — either local ([GETTING_STARTED.md](GETTING_STARTED.md)) or deployed ([DEPLOY.md](DEPLOY.md)) — from [ordered-load-tests](https://github.com/ordered-system/ordered-load-tests):

```bash
git clone https://github.com/ordered-system/ordered-load-tests.git
cd ordered-load-tests

make seed-load-test-data                 # populate the catalog first
make load-test                           # UserJourneySimulation — full mixed read/write flow
make load-test-cache-stress              # ProductCatalogStressSimulation — read-heavy
make smoke-test                          # correctness check: the whole business flow, once
```

Point it somewhere other than `localhost:8080` with `GATEWAY_URL`:

```bash
GATEWAY_URL=https://your-deployed-domain make smoke-test
```

`smoke-test` is the one to run after any deploy — it's not measuring throughput, it walks register → login → become seller → create product → browse → view → add to cart → place order → mark delivered → review, and fails loudly if any step breaks, which is a faster sanity check than clicking through the whole app by hand.

Gatling's HTML report for `load-test` / `load-test-cache-stress` is written under `target/gatling/` — the command output prints the exact path to open.

## Observability while testing

If you're running the local dev infra ([GETTING_STARTED.md](GETTING_STARTED.md)) or the full prod stack, every service exposes Micrometer metrics and OpenTelemetry traces — genuinely useful for *watching* a load test rather than just reading the summary afterwards:

- **Grafana** (`localhost:3000` locally, `grafana.<domain>` in prod) — the pre-provisioned `ordered-system-overview` dashboard.
- **Jaeger** (`localhost:16686` locally, `jaeger.<domain>` in prod) — full distributed traces across services for a single request, useful for seeing exactly where the latency in a slow request actually went.
