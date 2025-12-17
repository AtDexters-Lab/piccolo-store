# Repository Guidelines

## Project Structure & Module Organization

- `index.yaml`: Master catalog consumed by Piccolo (`piccolod`). Each entry points to an app manifest via `path`.
- `apps/<app-slug>/app.yaml`: App manifest (image, inputs, listeners, environment, storage).
- Optional per-app assets: `apps/<app-slug>/icon.png` and `apps/<app-slug>/README.md`.

When adding an app, keep these aligned: directory name (`apps/<slug>`), `app.yaml` `name`, and the `index.yaml` `name`/`path`.

## Build, Test, and Development Commands

This repo is data-only (YAML), so there’s no build step.

- `python3 -m http.server 8000`: Serve the repo locally for quick manual testing.
- `PICCOLO_APP_STORE_URL=http://localhost:8000 …`: Point Piccolo to your local store URL (restart `piccolod` as needed).
- `yamllint index.yaml apps/**/app.yaml`: Optional YAML lint (if `yamllint` is installed).

## Coding Style & Naming Conventions

- YAML: 2-space indentation, no tabs, keep formatting consistent with nearby files.
- Slugs: lowercase kebab-case (e.g., `apps/uptime-kuma`).
- Templates: quote templated strings (e.g., `name: "{{ .Inputs.subdomain }}"`).
- Images/versions: prefer pinned tags over `latest`, and keep `index.yaml` `version` consistent with the image tag you ship.

## Testing Guidelines

There’s no automated test suite in this repository. Before opening a PR:

- Ensure `index.yaml` references an existing `apps/<slug>/app.yaml`.
- Validate YAML syntax (manually or via `yamllint`).
- Avoid committing secrets: use `inputs` with `type: password` + `generate: true`, then reference via `environment`.

## Commit & Pull Request Guidelines

- Commits: short, imperative, and app-focused (examples from history: “Add configuration files for new applications…”, “init … repo”).
- PRs: include what changed, the app version/image tag, any new inputs/ports/storage, and a source link (release notes or upstream repo).

