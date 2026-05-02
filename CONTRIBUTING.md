# Contributing to piccolo-store

The catalog conventions are documented in [AGENTS.md](./AGENTS.md). The schema is documented at the upstream [piccolod app-platform spec](https://raw.githubusercontent.com/AtDexters-Lab/piccolod/refs/heads/main/docs/app-platform/specification.yaml). Plans for non-trivial catalog changes live under [docs/plans/](./docs/plans/).

## Hard rules — guardrails not to break

### Do not rename or remove the `index.yaml` `name:` of a service-mode app once it has shipped

**Why.** piccolod's catalog sync identifies installed apps by `appInst.CatalogSource`, which stores the **`index.yaml` `name:` field** the app was installed from. When a service-mode app's `name:` is renamed (or its `app.yaml` is removed and re-added under a different `name:`), `host.FetchCatalogTemplate(ctx, appInst.CatalogSource)` on the next sync attempt fails to find the old name. The sync silently logs a `WARN`; the install is not removed but stops receiving catalog updates entirely — no security patches, no schema migrations, no version bumps.

**The rule (precise scope).** This applies to:
- Any app in `index.yaml` whose corresponding `app.yaml` declares `x-piccolo.mode: service` (or omits `mode` while behaving as service-mode).
- The rule covers renames, **outright removals**, deletions-followed-by-re-additions-under-a-new-name, and any other change that breaks the `appInst.CatalogSource` lookup. (Removal has the same orphaning effect as a rename: existing installs continue running but silently stop receiving updates.)

**The rule applies to which fields, exactly.**
- ✋ **Forbidden to rename (for service-mode apps):** the `name:` field of the app's entry in `index.yaml`. This is what `appInst.CatalogSource` keys on.
- ✅ **Safe to change:** the directory under `apps/`, the `path:` field in `index.yaml`, the `description:`, `icon:`, `tags:`, `category:`, `maintainer:`, `source_url:`, and the `version:` field. None of these affect catalog sync's identity match.

**This rule does NOT apply to workspace-mode apps.** `catalog_sync.go` only runs sync on `mode: service` apps; workspace-mode apps are unaffected by name changes. (The May 2026 overhaul renamed `workspace-server-full` → `linux-vm` under this allowance.)

**Do not flip a previously-renamed workspace-mode app to service-mode.** If an app was ever renamed in its history (under the workspace-mode allowance) and is now being converted to service-mode, the rename now becomes load-bearing for catalog sync. Either keep the original `name:` for the service-mode variant, or introduce service-mode functionality under a fresh slug.

**If you need to break the rule** — for legitimate cases like (a) upstream is gone and the app is being retired, (b) confirmed nobody has the app installed in the field, or (c) you're consciously orphaning existing installs and have a migration plan — add `[ALLOW-RENAME]` to the PR title to bypass the CI check, and document the rationale in the PR description. The token's name covers both renames and removals (same failure mode).

**Enforcement.** [`.github/workflows/rename-safety.yml`](./.github/workflows/rename-safety.yml) runs on every PR that touches `apps/` or `index.yaml`. The check compares the set of `index.yaml` `name:` values between base and head; if any service-mode name is missing in head (rename or deletion, regardless of whether the on-disk `app.yaml` was touched), the PR fails unless the `[ALLOW-RENAME]` PR-title override is present. The check guards the actual orphaning trigger (catalog name change), not the on-disk file deletion — a rename that keeps the file in place is still caught.

### Other reminders

- All `apps/<app-slug>/app.yaml` files must conform to the [piccolod app-platform spec](https://raw.githubusercontent.com/AtDexters-Lab/piccolod/refs/heads/main/docs/app-platform/specification.yaml).
- Pin image tags to the version declared in `index.yaml` (avoid `:latest`). Exception: first-party rolling images (e.g., `ghcr.io/atdexters-lab/*`) may use `:latest` paired with `version: latest` in `index.yaml`.
- Use `inputs` with `type: password` + `generate: true` for secrets; reference via `environment` or `app_config`.
- Validate YAML before opening a PR (`yamllint index.yaml apps/**/app.yaml` if installed).
