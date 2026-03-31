# Piccolo Store

Official app catalog for Piccolo OS. Apps listed here are installable from the Piccolo portal.

![Stage: Alpha](https://img.shields.io/badge/Stage-Alpha-orange)

## Available Apps

Browse the **[app catalog](https://atdexters-lab.github.io/piccolo-store)** to see what's installable.

## Getting Started

These apps are installable from the Piccolo portal. Flash Piccolo OS onto your device — see [piccolo-os](https://github.com/AtDexters-Lab/piccolo-os) for install guides. Once running, browse and install apps from your device's web portal.

## How It Works

`piccolod` fetches the catalog from this repository at runtime. The default URL is:

```
https://raw.githubusercontent.com/AtDexters-Lab/piccolo-store/main
```

You can override this by setting the `PICCOLO_APP_STORE_URL` environment variable.

The catalog is defined in `index.yaml`, which points to individual app manifests under `apps/`. Each app directory contains:

- `app.yaml` — the Piccolo app manifest (container image, listeners, storage, etc.)
- `icon.png` — (optional) application icon
- `README.md` — (optional) app-specific documentation

## Adding or Updating an App

1. **Create app directory:** Create a new directory under `apps/` with your app's name (slug).
2. **Add `app.yaml`:** Define your application's container image, listeners, storage, etc.
3. **Update `index.yaml`:** Add an entry pointing to your new app.

The [app catalog](https://atdexters-lab.github.io/piccolo-store) is regenerated automatically by CI when `index.yaml` or `apps/` change.

### `index.yaml` Format

```yaml
apps:
  - name: my-app
    description: "A short description of my app."
    icon: "https://raw.githubusercontent.com/AtDexters-Lab/piccolo-store/main/apps/my-app/icon.png"
    version: "1.0.0"
    category: "Utilities"
    path: "apps/my-app/app.yaml"
    maintainer: "Me"
    tags: ["utility", "tool"]
    source_url: "https://github.com/example/my-app"
```

## The Piccolo Ecosystem

| Component | Role |
|-----------|------|
| [piccolo-os](https://github.com/AtDexters-Lab/piccolo-os) | OS images, install guides, and project hub |
| [piccolod](https://github.com/AtDexters-Lab/piccolod) | On-device daemon — portal, app management, encryption |
| [namek-server](https://github.com/AtDexters-Lab/namek-server) | Orchestrator — device auth, DNS, certificates |
| [nexus-proxy-server](https://github.com/AtDexters-Lab/nexus-proxy-server) | Edge relay — remote access with device-terminated TLS |
| [piccolo-store](https://github.com/AtDexters-Lab/piccolo-store) | App catalog — manifests for installable apps |

## License

AGPL-3.0 — see [LICENSE](./LICENSE).
