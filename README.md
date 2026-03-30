# Piccolo Store

Official app catalog for Piccolo OS. Apps listed here are installable from the Piccolo portal.

![Stage: Alpha](https://img.shields.io/badge/Stage-Alpha-orange)

## Available Apps

[Browse the full catalog](https://atdexters-lab.github.io/piccolo-store)

<!-- APPS_TABLE_START -->
| Name | Category | Version | Description |
|------|----------|---------|-------------|
| [Code Server](https://github.com/coder/code-server) | Development | 4.96.2 | VS Code in the browser |
| [ConvertX](https://github.com/C4illin/ConvertX) | Utilities | 0.16.1 | Self-hosted online file converter supporting 1000+ formats |
| [Homebox](https://github.com/sysadminsmedia/homebox) | Productivity | 0.16.0 | Inventory and asset management system |
| [Immich](https://github.com/immich-app/immich) | Media | v2 | High performance self-hosted photo and video management solution |
| [Namek](https://github.com/AtDexters-Lab/namek-server) | System | latest | Piccolo OS control plane — device auth, DNS, and token issuance |
| [Uptime Kuma](https://github.com/louislam/uptime-kuma) | Monitoring | 1.23.13 | A fancy self-hosted monitoring tool |
| [Vaultwarden](https://github.com/dani-garcia/vaultwarden) | Security | 1.33.0 | Unofficial Bitwarden compatible server written in Rust |
| [WordPress](https://wordpress.org) | CMS | 6.4 | Web software you can use to create a beautiful website, blog, or app |
| [Workspace Debian](https://hub.docker.com/r/linuxserver/webtop) | Workspace | bookworm | Full Debian MATE Desktop environment (Webtop) |
| [Workspace Server Full](https://hub.docker.com/_/microsoft-devcontainers-base) | Workspace | bookworm | Full Debian Server (DevContainer) with pre-installed utilities (Git, Zsh, Sudo) |
<!-- APPS_TABLE_END -->

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

The README table and [HTML catalog](https://atdexters-lab.github.io/piccolo-store) are regenerated automatically by CI when `index.yaml` or `apps/` change.

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
