#!/bin/bash

set -e  # Exit on error

# Pre-requisite check
command -v python3 >/dev/null 2>&1 || {
  echo "❌ python3 is required (used by scripts/strip_stretchable_markers.py) but was not found on PATH." >&2
  exit 1
}

# Config
BASE_URL="http://localhost:3000/sprite"
OUT_BASE="./generated_sprites"
BUILD_DIR="./.sprite_build"
THEMES=("light" "dark")
RESOLUTIONS=("" "@2x")

# Accept optional namespace args; default to all discovered namespaces
if [[ $# -gt 0 ]]; then
  NAMESPACES=("$@")
  echo "🔍 Using provided namespaces: ${NAMESPACES[*]}"
else
  echo "📂 Scanning sprite_assets for namespaces..."
  NAMESPACES=()
  for dir in sprite_assets/*/; do
    [ -d "$dir" ] && NAMESPACES+=("$(basename "$dir")")
  done
  echo "🔍 Found namespaces: ${NAMESPACES[*]}"
fi

# 1. Stop & remove existing container
echo "🔄 Stopping and removing any existing 'martin' container..."
docker stop martin >/dev/null 2>&1 || true
docker rm martin >/dev/null 2>&1 || true

# 2. Strip stretch/content marker fills, then build volume mounts and --sprite args
# (SVGs in sprite_assets/ carry visible marker rects - e.g. id="mapbox-content" -
# so Figma doesn't drop them as invisible shapes on export. They need to be made
# invisible before martin rasterises them, without touching the geometry martin
# reads their content/stretchX/stretchY from. See scripts/strip_stretchable_markers.py)
echo "🩹 Stripping stretch/content marker fills..."
rm -rf "$BUILD_DIR"

echo "📦 Building volume mounts and sprite args..."
VOLUME_ARGS=()
SPRITE_ARGS=()

for NAME in "${NAMESPACES[@]}"; do
  for THEME in "${THEMES[@]}"; do
    SRC_DIR="$(pwd)/sprite_assets/${NAME}/${THEME}"
    PROCESSED_DIR="$(pwd)/${BUILD_DIR}/${NAME}_${THEME}"
    mkdir -p "$PROCESSED_DIR"
    python3 scripts/strip_stretchable_markers.py "$SRC_DIR" "$PROCESSED_DIR"

    TARGET_DIR="/sprite_assets/${NAME}_${THEME}"
    VOLUME_ARGS+=(-v "${PROCESSED_DIR}:${TARGET_DIR}")
    SPRITE_ARGS+=(--sprite "${TARGET_DIR}")
  done
done

# 3. Build docker run command
DOCKER_CMD=(
  docker run -d
  --name martin
  -p 3000:3000
  "${VOLUME_ARGS[@]}"
  ghcr.io/maplibre/martin:v0.13.0
  "${SPRITE_ARGS[@]}"
)

# 4. Print full command for reference
echo "🐳 Docker command:"
printf '%q ' "${DOCKER_CMD[@]}"
echo

# 5. Run the container
echo "🚀 Starting 'martin' container..."
"${DOCKER_CMD[@]}"

# 6. Wait for it to boot up
echo "⏳ Waiting for martin to initialize..."
for i in {1..30}; do
  curl -sf http://localhost:3000/health >/dev/null && break
  sleep 1
done

# 7. Download sprite files
echo "⬇️ Downloading sprite images (.png and .json)..."
for NAME in "${NAMESPACES[@]}"; do
  OUT_DIR="${OUT_BASE}/${NAME}"
  mkdir -p "$OUT_DIR"

  for THEME in "${THEMES[@]}"; do
    for RES in "${RESOLUTIONS[@]}"; do
      for EXT in "png" "json"; do
        FILENAME="${THEME}${RES}.${EXT}"
        URL="${BASE_URL}/${NAME}_${FILENAME}"
        OUTPUT="${OUT_DIR}/${FILENAME}"

        echo "  ➤ Downloading ${URL}"
        curl -sf -o "${OUTPUT}" "${URL}"
      done
    done
  done
done

echo "✅ All sprites downloaded into $OUT_BASE/"

# 8. Shutdown
echo "🛑 Stopping and removing 'martin' container..."
docker stop martin >/dev/null
docker rm martin >/dev/null
echo "✅ Tile server shut down."
