# Catalog cohesive overhaul — May 2026

**Status:** plan, round 3 (post-review-2 revisions)
**Author:** Abhishek
**Date:** 2026-05-01
**Round 1 reviewers:** rfc-reviewer (RED, 7 findings) + rfc-red-team (YELLOW, 10 findings); resolved.
**Round 2 reviewers:** rfc-reviewer (GREEN, 3 polish significants) + rfc-red-team (RED, 3 blockers + 7 significants); convergent SPA-carve-out flaw drove the largest revision (uptime-kuma carve-out dropped entirely).

---

## Scope

**Problem:** The piccolo-store catalog drifted behind piccolod's evolved manifest schema (resource-stewardship, RFC 20260130 unified app identity, RFC 20260112 listener auth rules). Only `immich` is on the current shape. The remaining 9 apps are inconsistent (some are parser-rejected outright, some lack new required-by-policy blocks, image tags drift from declared versions, auth posture is implicit). Users installing apps today get inconsistent guarantees on resource gating, identity, replication, and auth.

**In scope:**
- Catalog hygiene: drop apps with no demonstrable user demand (wordpress, homebox); rename `workspace-server-full` → `linux-vm`.
- Schema correctness for all remaining apps: parser-rejected fields removed; image tags pinned to declared `index.yaml` versions; input types corrected.
- Resource-stewardship adoption (top-level `resources:` block) on every app missing it.
- Healthchecks via `healthcheck.http` for every app with an HTTP listener and a known liveness endpoint *(declarative metadata; no runtime poller in piccolod today — field is forward-looking)*.
- Auth posture made explicit per a single rule: strict-by-default; native-OIDC apps must use `oidc_passthrough`; public-content surfaces (status pages, public token endpoints, badges) carved out as `public`.
- Replication blocks (`x-piccolo.replication`) on stateful service-mode apps with non-transient data, using immich's hot+cold/[disk,data]/rpo 1h crash-consistent pattern.
- Confident upstream version bumps (only where the upstream changelog is unambiguously safe for an in-place mount).

**Out of scope:**
- Native OIDC integration for apps beyond immich (requires per-app init scripts and upstream OIDC support).
- Permissions hardening (`permissions.network.internet`, `allowed_domains` per app) — separate audit, deferred.
- Per-app `apps/<slug>/README.md` documentation.
- Replacing wordpress/homebox with alternatives.
- Healthcheck for `namek` — its primary listener is TLS passthrough.
- Touching `permissions:` defaults on any app.
- Touching the auto-generated `docs/index.html`.

---

## Background — what changed in piccolod since the catalog was last touched

Sources used to anchor every decision below: `../piccolod/internal/app/parser.go` (validation source of truth), `../piccolod/internal/app/smart_defaults.go` (UI input prep), `../piccolod/internal/app/install_pipeline.go` (install-time identity substitution), `../piccolod/internal/app/multi_container.go` (workspace boot wrapper / `init: image` semantics), `../piccolod/internal/app/catalog_sync.go` + `catalog_sync_apply.go` (per-instance sync model), `../piccolod/docs/runtime/resource-stewardship.md` (resources schema).

- **App identity (RFC 20260130):** no top-level `name`; identity comes from the `__primary` listener marker (catalog apps) or `workspace_name` (workspace mode without listeners). The `__app_address__` input is auto-injected by `smart_defaults.PrepareSmartDefaults` and substituted by `install_pipeline` over the placeholder at install time. **Critical clarification:** the YAML's `__primary` listener name and the YAML's `workspace_name` field are *parser-required placeholders*; runtime identity always comes from the user-prompted `__app_address__` input. The pattern is symmetric across service and workspace modes.
- **Top-level deprecated keys** (`image`, `environment`, `storage`, `auth`) — rejected by parser. Per-service only.
- **Service-field whitelist** (`image`, `init`, `init_script`, `after`, `bind_ports`, `environment`, `storage`, `oidc_client`) — anything else (e.g., `user`) fails with "unsupported field".
- **Workspace mode:** if no listeners, `workspace_name` (1–16 char, lowercase alphanumeric, no hyphens) is required at root *as a parser placeholder*; runtime identity comes from `__app_address__` per the install pipeline.
- **`init: image` for workspace mode** (`multi_container.go:169`): does NOT seed an empty disk. Means "let the container image's own init system (e.g., s6-overlay) be PID 1 instead of Piccolo's `boot.sh` keep-alive wrapper." Use only when the image *requires* its own init system (webtop/s6). Plain Debian images don't need it.
- **Listener auth (RFC 20260112):** `auth.rules` valid only on `flow:tcp + protocol:http|websocket`. Strategies: `public | protected | headers | oidc_passthrough`. Prefix paths must end with `/`. `oidc_passthrough` requires a service to declare `oidc_client`.
- **Resource-stewardship:** new top-level `resources:` block. Authors declare *shape*, runtime derives kernel knobs. Pre-v2 schemas (`services.X.resources`, `resources.limits`) are explicitly rejected.
- **Replication (`x-piccolo.replication`):** `hot.datasets` for near-real-time cross-device coherence; `cold.datasets` + `rpo` + `consistency` for backup horizon. Datasets: `disk` (Podman overlay+metadata), `data` (declared persistent volumes).
- **Healthcheck (`healthcheck.http`):** declared at app level; `port` field is the *listener name*. **Note:** as of this writing no piccolod component actively polls this — the field is metadata used for catalog-sync drift detection and forward-compat. Choosing a sensible value still matters for when the poller lands (likely RFC 20260125 listener-health follow-up).
- **`x-piccolo.secrets.injection`:** purely informational today (no piccolod code consumes it). Use `env` for env-only apps; `mixed` only for apps that actually materialize secrets to files (immich's init script does this).
- **Catalog sync model:** keyed by `appInst.InstanceID` and `appInst.CatalogSource` (the original catalog item name). Sync ONLY runs on `ModeService` apps (`catalog_sync.go:161`) — workspace mode apps don't auto-sync from the catalog.

---

## Plan — decisions and shapes per track

### Track H — catalog hygiene

**Decisions:**
- Remove `apps/wordpress/` and its `index.yaml` entry. Rationale: WordPress on a single-tenant personal-device OS is infrastructure overkill; the `soulteary/sqlite-wordpress` image we ship is a community fork (drops MariaDB) suggesting low real-world use.
- Remove `apps/homebox/` and its `index.yaml` entry. Rationale: niche use case, low demand signal. Confirmed user-side: nobody has it installed.
- Rename `apps/workspace-server-full/` → `apps/linux-vm/`. New `index.yaml` `name: linux-vm`, new `description: "A fresh Debian Linux server in your hand — like spinning up a cloud VM, but on your Piccolo"`. Workspace_name placeholder: `linuxvm`.
- Sharpen `workspace-debian` description: *"Debian MATE desktop in your browser — a full graphical workspace for general computing"*.
- **Rename safety (resolves S9 + RT#6):** workspace-server-full is `ModeWorkspace` → catalog sync never runs on it (`catalog_sync.go:161`). Combined with confirmed "nobody has it installed", the rename has zero orphaning risk regardless of piccolod's slug-rename support.

**Shape changes to `index.yaml`:** 10 entries → 8.

### Track A — schema correctness

**Decisions per app:**
- `apps/code-server/app.yaml`: image tag `:latest` → `:4.96.2` (matches `index.yaml`).
- `apps/vaultwarden/app.yaml`: image tag `:latest` → `:1.33.0` (matches `index.yaml`).
- `apps/convertx/app.yaml`: inputs `account_registration` and `allow_unauthenticated` change `type: string` → `type: boolean`; defaults change `"false"` → `false`.
- `apps/linux-vm/app.yaml` (post-rename): drop `services.main.user: vscode` (parser-rejected); add `workspace_name: linuxvm` placeholder. **Note (resolves F2/S6):** running as container-uid-0 is safe — per-app-user slices map container uid 0 to an unprivileged host uid via Linux user namespaces. No host-side privilege escalation.
- `apps/immich/app.yaml`: drop one stale commented `IMMICH_CONFIG_FILE` line.

**Note on uptime-kuma image (resolves S4/RT#4):** the intermediate pin `:1` → `:1.23.13` is intentionally **omitted** from Track A. Pinning to `1.23.13` would *downgrade* installs already on a later `:1` sha (no downgrade safety guarantee). Instead, uptime-kuma's image tag changes only once in Track I, going `:1` → `:2.3.0` directly.

### Track B — resource-stewardship adoption

**Shape:** every remaining app gets a top-level block of shape:

```
resources:
  priority: high | normal | background     # default normal
  memory:
    min_required: <size>                   # required when memory block declared
    profile: bounded | elastic             # default bounded
```

**Per-app values:**

| App | priority | min_required | profile |
|---|---|---|---|
| uptime-kuma | normal | 256MB | bounded |
| code-server | normal | 512MB | bounded |
| vaultwarden | normal | 256MB | bounded |
| convertx | normal | 512MB | bounded *(already adopted)* |
| workspace-debian | normal | 1GB | bounded |
| linux-vm | normal | 256MB | bounded |
| namek | normal | 1GB | bounded *(already adopted)* |
| immich | normal | 6GB | elastic *(already adopted, with `storage.max: 500GiB`)* |

**Note on workspace-debian profile** (resolves RT2-R2-8): originally `elastic`, revised to `bounded`. webtop+MATE's working set is largely fixed (desktop session + browser tabs); it doesn't cache opportunistically the way an ML thumbnailer does. With both workspace-debian and immich `elastic`, an 8GB box would sum two app-level MemoryMax ≈ 6.144 GiB ceilings — both can grow to that ceiling individually under N=2 elastic accounting, producing thrashing the install-time Tier 1 warn doesn't catch. `bounded` for workspace-debian gives `MemoryMax = min(2GB, 6.144 GiB) = 2 GB` — predictable, leaves headroom for immich.

**Acknowledged (A2):** Sum-of-floors across the typical install set (workspace-debian + code-server + uptime-kuma + vaultwarden + namek = 3GB) sits just under usable_RAM (3.2GB on 4GB) — adding immich (6GB floor) hard-blocks Tier 2 on 4GB hardware as expected. No mitigation needed; the resource-stewardship gate handles it.

### Track C — healthchecks

**Shape:**

```
healthcheck:
  http:
    path: <upstream-known-liveness-path>
    timeout: 10s
    retries: <per-app>
```

**Per-app paths and retry tuning:**

| App | path | retries | Notes |
|---|---|---|---|
| uptime-kuma | `/` | 5 | Generous retries to anticipate the v2 first-boot migration window when poller eventually lands |
| code-server | `/healthz` | 3 | Documented unauth liveness endpoint |
| vaultwarden | `/alive` | 3 | Documented liveness endpoint |
| convertx | `/favicon.ico` | 3 | Verified present in convertx's `public/` folder (Bun/Elysia, not SvelteKit — RT2-R2-6 misread). Returns 200 unconditionally regardless of `ALLOW_UNAUTHENTICATED`. |
| workspace-debian | `/` | 3 | Webtop root returns 200 |
| immich | `/api/server-info/ping` | 5 | Already adopted |
| linux-vm | (none) | — | No HTTP listener |
| namek | (deferred) | — | Primary is TLS passthrough; admin is protected; needs design |

**Note (resolves S1/RT#1, S8/F7):** healthcheck.http is currently declarative metadata only — no piccolod component polls it. None of the migration-window-restart or workspace-roam-lifecycle concerns are blocking *today*. Field choices are forward-looking for when the poller lands.

### Track D — explicit auth posture

**Catalog-wide rule:**
- Every listener's `auth.rules` is explicit (no relying on parser's implicit `protected` default).
- Strict-by-default: `protected` on `/` for apps without public-content surfaces.
- Native OIDC apps must use `oidc_passthrough` (only immich qualifies).
- Public-content surfaces explicitly carved out as `public` rules ordered before the catch-all.

**Per-app decision:**

| App | New auth rules | Reason |
|---|---|---|
| immich | unchanged (oidc_passthrough on `/` + public exceptions for `/.well-known/`, `/api/server-info/ping`) | Already correct |
| uptime-kuma | `public` on `/metrics` (exact); `protected` on `/` (catch-all) | **Revised from round 2 + 3.** uptime-kuma is a Vue SPA — visiting `/status/<slug>` triggers browser sub-requests to `/assets/...js`, `/socket.io/...`, `/favicon.png` etc. These don't match any *prefix*-based carve-out for status pages, fall to the `/` catch-all, and bounce to OIDC → status page renders blank. So we drop prefix-based carve-outs and accept the regression: **public status pages, public push monitors, and public badges do not work in this catalog version** (reintroducing needs a SPA-aware audit, out of scope). However, `/metrics` is an *exact* path — no SPA sub-request implication — and uptime-kuma's upstream provides its own production-grade auth on it (HTTP basic / API key per the Prometheus integration wiki). External Prometheus scrapers using upstream basic-auth credentials remain functional. Resolves RT2-R2-1 / RT2-R2-2 / RT2-R2-3 / R3-S-R3-1. |
| code-server | `protected` on `/` | Strict default |
| vaultwarden | `protected` on `/` | Strict default; vaultwarden has its own master password as defense-in-depth |
| convertx | `protected` on `/` | Strict default; convertx's `allow_unauthenticated` only affects convertx-internal auth, not Piccolo's gate |
| workspace-debian | `protected` on `/` | Strict default |
| linux-vm | n/a (no listeners) | Workspace, no HTTP surface |
| namek | unchanged (`protected` on `/admin/`; primary is TLS passthrough so no auth block applicable) | Already correct |

### Track G — replication blocks

**Shape** (from immich, the established reference):

```
x-piccolo:
  mode: service
  replication:
    hot:
      datasets: [disk, data]
    cold:
      datasets: [disk, data]
      rpo: 1h
      consistency: crash_consistent
  secrets:
    injection: env       # or 'mixed' only for apps with init_script-materialized secret files (immich)
```

**Apps it applies to (decision-resolved):**
- `apps/uptime-kuma/app.yaml` — has `/app/data` persistent volume (monitor history is high-value to replicate). Adopts the full immich pattern.
- `apps/vaultwarden/app.yaml` — has `/data` persistent volume (password vault — must roam). Adopts the full immich pattern.
- `apps/namek/app.yaml` — has `pgdata` persistent volume. **Revised from round 2: cold replication only, no `hot`.** Reason (RT2-R2-5): namek runs three services where `powerdns` reads zone configuration from PostgreSQL on every DNS query. Hot-replicating `pgdata` mid-write means PowerDNS on the receiving node serves DNS answers from a partial/stale view of the zone, producing user-visible DNS inconsistency. The deferred memory entry (`deferred_namek_replication_split_brain.md`) tracks the HA-design follow-up. namek shape:
  ```
  x-piccolo:
    mode: service
    replication:
      cold:
        datasets: [disk, data]
        rpo: 1h
        consistency: crash_consistent
    secrets:
      injection: env
  ```

  **Accepted DR cost (resolves R3-3 + RT3-A-R3-2):** cold-only replication with a 1-hour RPO is a non-trivial trade for a control-plane app. After a disaster (host loss + restore from most recent snapshot up to 1h old):
  - Devices that **enrolled in the last hour** before the disaster have their TPM-attested public keys absent from the restored pgdata. They appear "unknown" to namek post-restore — recovery is re-enrollment.
  - DNS A/AAAA records added in the last hour return NXDOMAIN until those devices re-register.
  - Short-lived device tokens issued in the last hour are unrecoverable; affected devices may need to re-authenticate.

  This posture is accepted because (a) eliminating split-brain on PowerDNS is the higher-value correctness gain, (b) namek's HA model is a separate design (D1 deferred), and (c) within the catalog overhaul scope, no smaller-RPO cold cadence is mechanically simpler than 1h. Worth revisiting when namek-HA design lands.

**Apps explicitly excluded:**
- `apps/convertx/app.yaml` — convertx's `/app/data` holds transient converted files users typically download immediately; replicating burns bandwidth/storage for no user value. Documented as a "stateful but not replication-worthy" pattern.
- Workspace-mode apps (`code-server`, `workspace-debian`, `linux-vm`) — workspace's `disk` already roams under the workspace mode contract.
- `immich` — already has it.

**Note on `secrets.injection` (resolves S10/RT#5):** the field is purely informational today; only immich uses `mixed` honestly because its init script writes to a secret file path. **Apps that adopt the replication block above (uptime-kuma, vaultwarden, namek) also declare `injection: env`** — they inject secrets only via environment variables. The field is *not* declared on apps without replication blocks (convertx, workspaces); the `x-piccolo.secrets` annotation is purposeful only when paired with replication semantics where secret-handling-vs-replication composition matters. Future behavioral wiring of this field will then have honest signal to act on within the apps that opted into replication.

### Track I — version bumps where confident

| App | image tag from → to | `index.yaml` version from → to | Rationale |
|---|---|---|---|
| vaultwarden | 1.33.0 → 1.35.8 | 1.33.0 → 1.35.8 | Minor within stable 1.x; Bitwarden-compat preserved |
| code-server | 4.96.2 → 4.117.0 | 4.96.2 → 4.117.0 | Tracks VS Code minor releases; mechanical |
| uptime-kuma | `:1` → `:2.3.0` | 1.23.13 → 2.3.0 | **Single-step major bump** — skips intermediate 1.23.13 pin to avoid downgrade risk for installs on later `:1` sha (S4/RT#4 mitigation). Per upstream wiki: image name / port / data dir unchanged; auto-migration on first boot. **Acknowledged upstream risk** (RT2-R2-7): v1→v2 migration may hang on installs with large monitor histories per upstream issue #7184. **No in-place upgrade exposure** — confirmed nobody has uptime-kuma installed today, so the catalog change applies only to fresh v2 installs (no migration). When piccolod gains a per-app upgrade-announce mechanism, future major bumps should use it. |
| convertx | v0.16.1 → v0.17.0 | 0.16.1 → 0.17.0 | Pre-1.0; release notes document no manifest-impacting changes |

**Apps not bumped:**
- immich (floating `v2`); `index.yaml` version stays `v2`.
- namek (first-party `:latest`); `index.yaml` version stays `latest`.
- workspace-debian (linuxserver `:debian-mate` rolling); `index.yaml` version stays `bookworm`.
- linux-vm (devcontainers `:debian` rolling); `index.yaml` version stays `bookworm` (resolves F-R2-3 — explicitly inheriting from the workspace-server-full entry).

---

## Site list (Q1 of plan completeness test)

Every file that will read, write, or compose with the new behavior:

**Modified:**
- `apps/uptime-kuma/app.yaml` — Tracks B (resources), C (healthcheck `/` retries:5), D (single `protected` rule on `/` — carve-out dropped per round 2), G (replication hot+cold, secrets.injection: env), I (image tag `:1` → `:2.3.0` — Track A's intermediate pin skipped per S4 resolution)
- `apps/code-server/app.yaml` — Tracks A (image pin `:latest` → `:4.96.2`), B (resources), C (healthcheck `/healthz`), D (explicit `protected`), I (`:4.96.2` → `:4.117.0`)
- `apps/vaultwarden/app.yaml` — Tracks A (image pin `:latest` → `:1.33.0`), B (resources), C (healthcheck `/alive`), D (explicit `protected`), G (replication hot+cold, secrets.injection: env), I (`:1.33.0` → `:1.35.8`)
- `apps/convertx/app.yaml` — Tracks A (input types boolean), C (healthcheck `/favicon.ico`), D (explicit `protected`), I (image bump `:0.16.1` → `:0.17.0`). **Excluded from Track G.**
- `apps/workspace-debian/app.yaml` — Tracks B (resources `bounded` 1GB), C (healthcheck `/`), D (explicit `protected`)
- `apps/namek/app.yaml` — Track G only (replication **cold-only**, secrets.injection: env)
- `apps/immich/app.yaml` — Track A nit only (drop commented line); secrets.injection stays `mixed` (it really is)
- `index.yaml` — Track H (remove wordpress + homebox; rename workspace-server-full → linux-vm; sharpen descriptions; explicit version updates per Track I table)
- `CONTRIBUTING.md` — **New file (round 3 addition).** Captures the rule about service-mode slug renames (RT2-R2-9), with explicit scope: applies to the `index.yaml` `name:` field (not directory or `path:`); covers deletion-then-re-add and workspace→service mode flips; `[ALLOW-RENAME]` PR-title override.
- `.github/workflows/rename-safety.yml` — **New file (round 3 addition).** CI workflow enforcing the CONTRIBUTING.md rule (resolves R3-S-R3-3). Fails any PR that removes/renames a `mode: service` `app.yaml` without `[ALLOW-RENAME]` in the PR title. ~30 lines bash inside an Actions step.

**Created:**
- `apps/linux-vm/app.yaml` — Tracks H (rename target), A (drop `user: vscode`, add `workspace_name: linuxvm` placeholder), B (resources)

**Deleted:**
- `apps/workspace-server-full/app.yaml` — superseded by linux-vm
- `apps/wordpress/app.yaml` — Track H removal
- `apps/homebox/app.yaml` — Track H removal

**Auto-regenerated by CI (not edited):**
- `docs/index.html` — built from `index.yaml`

**Composes with but not modified (verified during plan review):**
- `../piccolod/internal/app/parser.go` — validates manifests; verified each shape passes.
- `../piccolod/internal/app/smart_defaults.go` — auto-injects `__app_address__` for `__primary` and for workspace-no-listeners; relied on for linux-vm identity.
- `../piccolod/internal/app/install_pipeline.go` — substitutes `__app_address__` over placeholders at install; relied on for both service-mode `__primary` and workspace-mode `workspace_name`.
- `../piccolod/internal/app/multi_container.go` — workspace boot wrapper logic (`init: image` semantics).
- `../piccolod/internal/app/catalog_sync*.go` — sync only runs on ModeService; relied on for the rename safety claim.

---

## Composition-blindness audit (Q3 of plan completeness test)

For each new behavior, every existing site that observes it has been verified.

### linux-vm identity model
- `workspace_name: linuxvm` is a parser-required placeholder satisfying `parser.go:786-788`'s static check. At install time, `smart_defaults.PrepareSmartDefaults` injects an `__app_address__` input (auto-labeled "Workspace Name") with default `sanitizeForHostname("linux-vm")` = `"linuxvm"`. `FindFreeName` bumps to `linuxvm1`, `linuxvm2`, etc. on collision. `install_pipeline.go:493-523` reads `__app_address__` from user inputs and overrides `def.WorkspaceName` with the user's value. **Result:** symmetric with how `__primary` works for service-mode apps; multi-install collision avoidance built-in.

### linux-vm `init: image` decision
- `multi_container.go:169` shows `init: image` *opts out* of Piccolo's workspace `boot.sh` wrapper, letting the image's own init system be PID 1. Used by workspace-debian because webtop/s6-overlay needs PID 1. Devcontainers base image has no such requirement; Piccolo's boot.sh keep-alive is the right default. **Decision:** linux-vm omits `init: image`.

### linux-vm root container user
- `services.main.user: vscode` is parser-rejected. Removing it leaves the container running as image-default (uid 0). Per Linux user-namespace mapping under per-app-user systemd slices, container uid 0 maps to an unprivileged host uid. No host-side privilege escalation. The "fresh cloud VM" UX matches user expectations for this app class.

### Resource-stewardship across apps
- Block is additive; apps without it fall back to runtime defaults. Adopting it activates install-time admission gating per `runtime/resource-stewardship.md`.
- Verified: every app's `min_required` is below 4GB, no Tier 2 hard blocks. Sum stays within usable_RAM for typical install sets.

### Replication adoption (uptime-kuma, vaultwarden, namek)
- Each app's persistent volumes are replication-worthy: vaultwarden's vault (must roam), uptime-kuma's monitor history, namek's PostgreSQL.
- convertx **excluded** (per S5 decision) — `/app/data` is transient.
- `crash_consistent` on PostgreSQL (namek) is recoverable via WAL replay for single-node restore. *(Federation/split-brain semantics under hot replication is captured as deferred memory `deferred_namek_replication_split_brain.md` — namek HA is a separate design.)*
- **Replication block accepts `cold` without `hot`** (resolves R3-5). `parser.go`'s `validateReplication` (around the `x-piccolo` extension validators) treats `hot` and `cold` as independently optional sub-blocks; the immich pattern declares both, but namek can declare only `cold` without parser rejection. Implementer to confirm during PR 5 prep with a `ParseAppDefinition` smoke test on the namek manifest pre-merge.

### Auth posture flips
- **uptime-kuma:** `protected` on `/` (catch-all) + `public` exact rule on `/metrics`. The Vue-SPA reasoning excludes prefix-based carve-outs for status pages / push monitors / badges (their browser sub-requests fall to the protected catch-all and render blank). `/metrics` is structurally different — exact path, single GET, no SPA sub-request implication — and uptime-kuma's upstream provides its own basic-auth on it, so the carve-out is safe and preserves the external-Prometheus integration. **Accepted regressions:** public status pages, public push monitors, and public badges. Reintroducing them needs a proper SPA-aware audit.
- **convertx:** Piccolo's `protected` strategy gates before convertx's own auth. `allow_unauthenticated: true` (if user sets it) only bypasses convertx-internal auth, never Piccolo's session gate. Acceptable per the strict-by-default rule.
- **vaultwarden, code-server, workspace-debian:** explicit `protected` makes the parser's implicit default visible. Each app has its own auth as defense-in-depth.

### secrets.injection field honesty
- immich keeps `mixed` (its init script materializes credentials to a Node-readable file via env-passed values).
- uptime-kuma, vaultwarden, namek (the apps that adopted the Track G replication block) also declare `injection: env`. The annotation is paired with replication so the field has clear meaning ("how does this app's secret-handling compose with the replicated datasets").
- Apps without replication (convertx, workspaces) deliberately do NOT declare `secrets.injection` — annotating the field on apps where it has no replication composition would be metadata noise. When piccolod wires behavioral semantics, the field will be evaluated only on apps where it carries signal.

### Catalog rename safety
- `catalog_sync.go:161` skips non-ModeService apps. workspace-server-full → linux-vm rename has zero sync impact; existing installs (none confirmed) wouldn't sync regardless. The workspace-mode rename safety established here **does NOT generalize to service-mode renames** — see CONTRIBUTING.md for the explicit guardrail (RT2-R2-9 resolution).
- For service-mode renames in the future: `appInst.CatalogSource` stores the original catalog item name and is used to fetch updates. A slug rename silently stops updates from reaching existing installs (sync errors logged, app not removed). Forbidden in CONTRIBUTING.md until piccolod ships catalog aliasing.

### Image tag pinning
- uptime-kuma's intermediate pin from Track A skipped — direct `:1` → `:2.3.0` in Track I avoids downgrade risk.
- code-server, vaultwarden pinning is forward (older → newer) — no downgrade risk.

---

## Default-by-omission audit (Q2 of plan completeness test)

Every site has named behavior:

- Every app gets *either* an explicit `auth.rules` block *or* documented n/a (linux-vm: no listeners; namek primary: TLS passthrough).
- Every app gets *either* a `resources` block (Track B per-app values) *or* "already adopted" call-out.
- Every app gets *either* a `healthcheck` block with a per-app path *or* explicit "deferred — needs design" (namek) or "no listeners" (linux-vm).
- Every app gets *either* a `replication` block (uptime-kuma, vaultwarden, namek) *or* explicit exclusion rationale (convertx: transient data; workspaces: disk roams).
- Every app gets *either* `secrets.injection: env` (env-only) *or* `mixed` (immich's init-script-materialized secrets).

No site has implicit behavior left to the implementer.

---

## Sequence — PR breakdown

Tracks land as separate commits, smallest mechanical first. Each is independently reviewable and revertible.

1. **PR 1: Track H (catalog hygiene) + CONTRIBUTING.md guardrail + rename-safety CI** — removes wordpress + homebox; renames workspace-server-full → linux-vm with `workspace_name` + `user: vscode` blockers fixed; sharpens descriptions; lands CONTRIBUTING.md rule on service-mode `name:` renames/removals; lands `.github/workflows/rename-safety.yml` to enforce the rule. **PR 1 title must include `[ALLOW-RENAME]`** — wordpress + homebox are `mode: service` apps being removed, which the CI check correctly blocks by default. The override is justified per CONTRIBUTING.md case (b): confirmed nobody has these installed in the field. workspace-server-full's removal does NOT need the override (it is `mode: workspace`, exempted by the check).
2. **PR 2: Track A (schema correctness)** — image-tag pinning (code-server, vaultwarden), convertx input types, immich nit. **Note:** uptime-kuma intentionally NOT pinned here; deferred to PR 6 to avoid intermediate downgrade risk.
3. **PR 3: Tracks B + C (resource-stewardship + healthchecks)** — single mechanical pass per remaining app. workspace-debian uses `bounded` (revised round 2). Per-app retries tuned (uptime-kuma: 5 for migration window).
4. **PR 4: Track D (explicit auth posture)** — `protected` on `/` for every HTTP-listener app. uptime-kuma is single-rule `protected` (no carve-outs).
5. **PR 5: Track G (replication blocks + honest secrets.injection)** — uptime-kuma + vaultwarden adopt immich's full hot+cold pattern. namek gets cold-only. convertx explicitly excluded. All non-immich apps declare `injection: env`.
6. **PR 6: Track I (version bumps)** — vaultwarden 1.33→1.35.8, code-server 4.96.2→4.117.0, uptime-kuma `:1`→`:2.3.0` (single step), convertx 0.16.1→0.17.0. PR 6 commit body documents the v1→v2 migration behavior for record-keeping; no in-place upgrade users are affected (confirmed nobody has uptime-kuma installed today).

Each PR's commit message includes per-app rationale + reference to this plan.

---

## Forward-compat notes (acknowledged, not in this plan)

- **F6/A1: `lifecycle:` namespace** reserved for future stop-on-idle RFC. No app declares it today (consistent with immich). When the RFC lands, every catalog manifest needs a per-app `lifecycle:` audit.
- **Healthcheck poller wiring** — when piccolod adds an active healthcheck poller (likely RFC 20260125 follow-up), revisit per-app retries/timeouts and the workspace-mode-during-roam interaction (S8/F7 — currently not concerning since no poller).
- **Service-mode catalog slug rename aliasing** — future renames of service-mode apps need a piccolod-side aliasing story to avoid silently orphaning sync. **Guardrail in this plan:** CONTRIBUTING.md (PR 1) explicitly forbids service-mode slug renames until that aliasing lands.
- **Workspace-mode install pipeline fail-soft** (RT2-R2-4 deferred): when `len(def.Listeners) == 0` and `__app_address__` user input is missing, `install_pipeline.go:493-523` silently falls back to the YAML's `workspace_name` placeholder rather than failing fast (asymmetric with the service-mode `__primary` path which errors). Outside the catalog's control; captured in `~/.claude/projects/-home-abhishek-borar-projects-piccolo-piccolo-store/memory/deferred_piccolod_workspace_install_failsoft.md` for piccolod-side follow-up.
- **`secrets.injection` field semantics** (F-R2-5 / RT2-R2-10 deferred): `injection: env` doesn't fully describe namek's `app_config` template injection (which materializes to a YAML file inside the container). When piccolod wires behavioral semantics into this field, namek may need a third value (e.g., `config_template`). Captured in `~/.claude/projects/-home-abhishek-borar-projects-piccolo-piccolo-store/memory/deferred_secrets_injection_semantics.md`.

## Deferred for later (adjacent findings captured per `policies/synthesis.md`)

- **D1 (RT#8 + RT2-R2-5) namek replication HA semantics** — current plan sidesteps the issue with cold-only replication; revisit when namek's HA model is designed. Captured at `~/.claude/projects/-home-abhishek-borar-projects-piccolo-piccolo-store/memory/deferred_namek_replication_split_brain.md`.
- **D2 (RT2-R2-4) piccolod workspace install fail-soft** — install_pipeline silently consumes `workspace_name` placeholder when `__app_address__` missing; asymmetric with `__primary` path fail-fast. Captured at `~/.claude/projects/-home-abhishek-borar-projects-piccolo-piccolo-store/memory/deferred_piccolod_workspace_install_failsoft.md`.
- **D3 (F-R2-5 + RT2-R2-10) `secrets.injection` field doesn't fit namek's app_config template injection** — revisit when piccolod wires behavioral semantics. Captured at `~/.claude/projects/-home-abhishek-borar-projects-piccolo-piccolo-store/memory/deferred_secrets_injection_semantics.md`.
