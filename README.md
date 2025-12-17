# Piccolo Store

This is the official app catalog for Piccolo OS. It provides a curated list of applications that are compatible with Piccolo.

## Structure

The repository is structured as follows:

- `index.yaml`: The master registry of all available applications. It contains metadata like name, description, version, and the path to the app's definition.
- `apps/`: A directory containing the application definitions.
    - `<app-name>/`: A subdirectory for each application.
        - `app.yaml`: The Piccolo app definition file (App Manifest).
        - `icon.png`: (Optional) The application icon.
        - `README.md`: (Optional) Documentation for the app.

## Adding or Updating an App

1.  **Create App Directory:** Create a new directory under `apps/` with your app's name (slug).
2.  **Add `app.yaml`:** Create the `app.yaml` file defining your application's container image, listeners, storage, etc.
3.  **Update `index.yaml`:** Add an entry to `index.yaml` pointing to your new app.

### `index.yaml` Format

```yaml
apps:
  - name: my-app
    description: "A short description of my app."
    icon: "https://raw.githubusercontent.com/AtDexters-Lab/piccolo-store/main/apps/my-app/icon.png"
    version: "1.0.0"
    category: "Utilities"
    compatibility: ">=0.1.0"
    path: "apps/my-app/app.yaml"
    maintainer: "Me"
    tags: ["utility", "tool"]
```

## URL

The default URL used by `piccolod` is `https://raw.githubusercontent.com/AtDexters-Lab/piccolo-store/main`. You can override this by setting the `PICCOLO_APP_STORE_URL` environment variable.