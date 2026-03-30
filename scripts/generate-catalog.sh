#!/usr/bin/env bash
# Generates the README apps table and HTML catalog page from index.yaml.
# Requires: yq v4+ (https://github.com/mikefarah/yq)
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
INDEX="$REPO_ROOT/index.yaml"
README="$REPO_ROOT/README.md"
DOCS_DIR="$REPO_ROOT/docs"

# --- Validate prerequisites ---
command -v yq >/dev/null 2>&1 || { echo "Error: yq v4 is required. Install from https://github.com/mikefarah/yq"; exit 1; }
[[ -f "$INDEX" ]] || { echo "Error: index.yaml not found at $INDEX"; exit 1; }
[[ -f "$README" ]] || { echo "Error: README.md not found at $README"; exit 1; }

if ! grep -q '<!-- APPS_TABLE_START -->' "$README"; then
  echo "Error: <!-- APPS_TABLE_START --> marker missing from README.md"
  echo "Fix: Add <!-- APPS_TABLE_START --> and <!-- APPS_TABLE_END --> markers to README.md"
  exit 1
fi
if ! grep -q '<!-- APPS_TABLE_END -->' "$README"; then
  echo "Error: <!-- APPS_TABLE_END --> marker missing from README.md"
  echo "Fix: Add <!-- APPS_TABLE_START --> and <!-- APPS_TABLE_END --> markers to README.md"
  exit 1
fi

# --- Helper: HTML-escape a string ---
html_escape() {
  local s="$1"
  s="${s//&/&amp;}"
  s="${s//</&lt;}"
  s="${s//>/&gt;}"
  s="${s//\"/&quot;}"
  s="${s//\'/&#39;}"
  printf '%s' "$s"
}

# --- Helper: Convert kebab-case to Title Case ---
# Override map for names where auto-conversion is wrong
declare -A DISPLAY_NAME_OVERRIDES=(
  [convertx]="ConvertX"
  [wordpress]="WordPress"
  [immich]="Immich"
)

to_title_case() {
  local name="$1"
  if [[ -n "${DISPLAY_NAME_OVERRIDES[$name]+x}" ]]; then
    printf '%s' "${DISPLAY_NAME_OVERRIDES[$name]}"
    return
  fi
  # Replace hyphens with spaces, capitalize each word
  echo "$name" | tr '-' ' ' | awk '{for(i=1;i<=NF;i++) $i=toupper(substr($i,1,1)) substr($i,2)}1'
}

# --- Helper: Escape pipe chars for markdown tables ---
md_escape_pipes() {
  local s="$1"
  printf '%s' "${s//|/\\|}"
}

# =============================================================================
# Extract all app data once
# =============================================================================
DATA_FILE=$(mktemp)
TABLE_FILE=$(mktemp)
README_TMP="$README.tmp"
trap 'rm -f "$DATA_FILE" "$TABLE_FILE" "$README_TMP"' EXIT

yq -r '.apps[] | [.name, .category, .version // "", .description // "", .source_url // "", .icon // ""] | @tsv' "$INDEX" \
  | sort -t$'\t' -k1,1 > "$DATA_FILE"

APP_COUNT=$(wc -l < "$DATA_FILE")

# =============================================================================
# PART 1: Generate README apps table
# =============================================================================
echo "Generating README apps table..."

{
  echo "| Name | Category | Version | Description |"
  echo "|------|----------|---------|-------------|"
} > "$TABLE_FILE"

while IFS=$'\t' read -r name category version description source_url _icon; do
  display_name=$(to_title_case "$name")
  description=$(md_escape_pipes "$description")

  if [[ -n "$source_url" && "$source_url" == https://* ]]; then
    echo "| [$display_name]($source_url) | $category | $version | $description |"
  else
    echo "| $display_name | $category | $version | $description |"
  fi
done < "$DATA_FILE" >> "$TABLE_FILE"

# Inject table into README between markers using awk
awk -v table_file="$TABLE_FILE" '
  /<!-- APPS_TABLE_START -->/ {
    print
    while ((getline line < table_file) > 0) print line
    skip = 1
    next
  }
  /<!-- APPS_TABLE_END -->/ {
    skip = 0
    print
    next
  }
  !skip { print }
' "$README" > "$README.tmp"
mv "$README.tmp" "$README"

echo "  README table updated ($(grep -c '^|' "$TABLE_FILE") rows)"

# =============================================================================
# PART 2: Generate HTML catalog page
# =============================================================================
echo "Generating HTML catalog page..."

mkdir -p "$DOCS_DIR"

# --- Category color map ---
category_color() {
  case "$1" in
    Media)        echo "#e74c3c" ;;
    Security)     echo "#9b59b6" ;;
    Monitoring)   echo "#3498db" ;;
    Development)  echo "#2ecc71" ;;
    CMS)          echo "#e67e22" ;;
    Productivity) echo "#1abc9c" ;;
    Utilities)    echo "#f39c12" ;;
    Workspace)    echo "#34495e" ;;
    System)       echo "#7f8c8d" ;;
    *)            echo "#95a5a6" ;;
  esac
}

# --- Write HTML header ---
cat > "$DOCS_DIR/index.html" << 'HTMLEOF'
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>Piccolo Store — App Catalog</title>
  <meta name="description" content="Official app catalog for Piccolo OS. Browse self-hosted apps installable from the Piccolo portal.">
  <meta property="og:title" content="Piccolo Store">
  <meta property="og:description" content="Official app catalog for Piccolo OS. Browse self-hosted apps installable from the Piccolo portal.">
  <meta property="og:type" content="website">
  <style>
    *, *::before, *::after { box-sizing: border-box; margin: 0; padding: 0; }

    :root {
      --bg: #ffffff;
      --bg-card: #f8f9fa;
      --text: #1a1a2e;
      --text-muted: #6c757d;
      --border: #e2e8f0;
      --shadow: rgba(0, 0, 0, 0.06);
    }

    @media (prefers-color-scheme: dark) {
      :root {
        --bg: #0f172a;
        --bg-card: #1e293b;
        --text: #e2e8f0;
        --text-muted: #94a3b8;
        --border: #334155;
        --shadow: rgba(0, 0, 0, 0.3);
      }
    }

    body {
      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Oxygen, Ubuntu, sans-serif;
      background: var(--bg);
      color: var(--text);
      line-height: 1.6;
      min-height: 100vh;
      display: flex;
      flex-direction: column;
    }

    header {
      text-align: center;
      padding: 3rem 1rem 2rem;
    }

    header h1 {
      font-size: 2rem;
      font-weight: 700;
      margin-bottom: 0.5rem;
    }

    header p {
      color: var(--text-muted);
      font-size: 1.1rem;
      max-width: 480px;
      margin: 0 auto;
    }

    header a {
      color: var(--text-muted);
      text-decoration: underline;
    }

    main { flex: 1; max-width: 1100px; width: 100%; margin: 0 auto; padding: 0 1rem 2rem; }

    .category-section { margin-bottom: 2.5rem; }
    .category-section h2 {
      font-size: 1.25rem;
      font-weight: 600;
      margin-bottom: 1rem;
      padding-bottom: 0.5rem;
      border-bottom: 2px solid var(--border);
    }

    .stack-section { margin-top: 3rem; border-top: 2px solid var(--border); padding-top: 2rem; }
    .stack-desc {
      color: var(--text-muted);
      font-size: 0.95rem;
      max-width: 640px;
      margin-bottom: 1.25rem;
    }

    .grid {
      display: grid;
      grid-template-columns: repeat(auto-fill, minmax(320px, 1fr));
      gap: 1rem;
    }

    .card {
      background: var(--bg-card);
      border: 1px solid var(--border);
      border-radius: 10px;
      padding: 1.25rem;
      display: flex;
      gap: 1rem;
      align-items: flex-start;
      box-shadow: 0 1px 3px var(--shadow);
      transition: box-shadow 0.15s;
    }

    .card:hover { box-shadow: 0 4px 12px var(--shadow); }

    .card-icon {
      width: 48px;
      height: 48px;
      flex-shrink: 0;
      border-radius: 8px;
      overflow: hidden;
      display: flex;
      align-items: center;
      justify-content: center;
    }

    .card-icon img {
      width: 100%;
      height: 100%;
      object-fit: contain;
    }

    .icon-placeholder {
      width: 100%;
      height: 100%;
      display: flex;
      align-items: center;
      justify-content: center;
      font-size: 1.25rem;
      font-weight: 700;
      color: #fff;
      border-radius: 8px;
    }

    .card-body { flex: 1; min-width: 0; }

    .card-title {
      font-size: 1rem;
      font-weight: 600;
      margin-bottom: 0.15rem;
    }

    .card-title a {
      color: var(--text);
      text-decoration: none;
    }

    .card-title a:hover { text-decoration: underline; }

    .card-meta {
      display: flex;
      gap: 0.5rem;
      align-items: center;
      margin-bottom: 0.4rem;
      flex-wrap: wrap;
    }

    .badge {
      font-size: 0.7rem;
      font-weight: 600;
      padding: 0.15rem 0.5rem;
      border-radius: 999px;
      color: #fff;
      text-transform: uppercase;
      letter-spacing: 0.03em;
    }

    .version {
      font-size: 0.75rem;
      color: var(--text-muted);
    }

    .card-desc {
      font-size: 0.875rem;
      color: var(--text-muted);
      line-height: 1.5;
    }

    footer {
      text-align: center;
      padding: 2rem 1rem;
      color: var(--text-muted);
      font-size: 0.85rem;
      border-top: 1px solid var(--border);
    }

    footer a { color: var(--text-muted); }
  </style>
</head>
<body>
  <header>
    <h1>Piccolo Store</h1>
    <p>Official app catalog for <a href="https://github.com/AtDexters-Lab/piccolo-os">Piccolo OS</a>. Install any of these from your device's web portal.</p>
  </header>
  <main>
HTMLEOF

# --- Collect categories in order ---
CATEGORIES=()
declare -A CATEGORY_CARDS

while IFS=$'\t' read -r name category version description source_url icon; do
  display_name=$(to_title_case "$name")
  safe_desc=$(html_escape "$description")
  safe_name=$(html_escape "$display_name")
  color=$(category_color "$category")
  first_letter="$(html_escape "${display_name:0:1}")"

  # Format version display
  if [[ "$version" == v* || ! "$version" =~ ^[0-9] ]]; then
    version_display="$version"
  else
    version_display="v${version}"
  fi

  # Build icon HTML
  if [[ -n "$icon" && "$icon" == https://* ]]; then
    icon_html="<img src=\"$(html_escape "$icon")\" alt=\"\" loading=\"lazy\">"
    placeholder_html="<div class=\"icon-placeholder\" style=\"background:${color};display:none\">${first_letter}</div>"
  else
    icon_html=""
    placeholder_html="<div class=\"icon-placeholder\" style=\"background:${color}\">${first_letter}</div>"
  fi

  # Build link
  if [[ -n "$source_url" && "$source_url" == https://* ]]; then
    name_html="<a href=\"$(html_escape "$source_url")\">${safe_name}</a>"
  else
    name_html="${safe_name}"
  fi

  card="    <div class=\"card\">
      <div class=\"card-icon\">${icon_html}${placeholder_html}</div>
      <div class=\"card-body\">
        <div class=\"card-title\">${name_html}</div>
        <div class=\"card-meta\">
          <span class=\"badge\" style=\"background:${color}\">$(html_escape "$category")</span>
          <span class=\"version\">${version_display}</span>
        </div>
        <div class=\"card-desc\">${safe_desc}</div>
      </div>
    </div>"

  # Group by category
  if [[ -z "${CATEGORY_CARDS[$category]+x}" ]]; then
    CATEGORIES+=("$category")
    CATEGORY_CARDS[$category]=""
  fi
  CATEGORY_CARDS[$category]+="$card"$'\n'

done < "$DATA_FILE"

# --- Define category display order (user-facing first, system last) ---
ORDERED_CATEGORIES=()
# Separate System from user-facing categories
for cat in Media Security Monitoring Development CMS Productivity Utilities Workspace; do
  if [[ -n "${CATEGORY_CARDS[$cat]+x}" ]]; then
    ORDERED_CATEGORIES+=("$cat")
  fi
done
# Add any remaining non-System categories not in the predefined order
for cat in "${CATEGORIES[@]}"; do
  [[ "$cat" == "System" ]] && continue
  if [[ ! " ${ORDERED_CATEGORIES[*]} " =~ " ${cat} " ]]; then
    ORDERED_CATEGORIES+=("$cat")
  fi
done

# --- Write user-facing category sections ---
for cat in "${ORDERED_CATEGORIES[@]}"; do
  cat >> "$DOCS_DIR/index.html" << SECTIONEOF
    <section class="category-section">
      <h2>$(html_escape "$cat")</h2>
      <div class="grid">
${CATEGORY_CARDS[$cat]}      </div>
    </section>
SECTIONEOF
done

# --- Write "Self-host the full stack" section for System apps ---
if [[ -n "${CATEGORY_CARDS[System]+x}" ]]; then
  cat >> "$DOCS_DIR/index.html" << 'STACKEOF'
    <section class="category-section stack-section">
      <h2>Self-host the full stack</h2>
      <p class="stack-desc">Piccolo OS is open source top to bottom — including the orchestrator. Install Namek on a second device and run your own control plane. No account required, no managed service dependency.</p>
      <div class="grid">
STACKEOF
  cat >> "$DOCS_DIR/index.html" << SECTIONEOF
${CATEGORY_CARDS[System]}      </div>
    </section>
SECTIONEOF
fi

# --- Write HTML footer ---
cat >> "$DOCS_DIR/index.html" << 'HTMLEOF'
  </main>
  <footer>
    <p>
      Generated from
      <a href="https://github.com/AtDexters-Lab/piccolo-store">piccolo-store/index.yaml</a>
      &middot;
      <a href="https://github.com/AtDexters-Lab/piccolo-os">Piccolo OS</a>
    </p>
  </footer>
  <script>
    // Fallback: show placeholder when icon fails to load
    document.querySelectorAll('.card-icon img').forEach(function(img) {
      img.addEventListener('error', function() {
        this.style.display = 'none';
        var placeholder = this.nextElementSibling;
        if (placeholder) placeholder.style.display = 'flex';
      });
    });
  </script>
</body>
</html>
HTMLEOF

# --- Create .nojekyll ---
touch "$DOCS_DIR/.nojekyll"

echo "  HTML catalog written to docs/index.html"
echo "Done. ${APP_COUNT} apps processed."
