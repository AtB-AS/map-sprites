#!/bin/bash

set -e  # Exit on error

# Config
BASE_URL="http://localhost:3000/sprite"
OUT_BASE="./generated_sprites"
THEMES=("light" "dark")
RESOLUTIONS=("" "@2x")

# Discover namespaces from folder structure
echo "📂 Scanning sprite_assets for namespaces..."
NAMESPACES=()
for dir in sprite_assets/*/; do
  [ -d "$dir" ] && NAMESPACES+=("$(basename "$dir")")
done

echo "🔍 Found namespaces: ${NAMESPACES[*]}"

# 1. Stop & remove existing container
echo "🔄 Stopping and removing any existing 'martin' container..."
docker stop martin >/dev/null 2>&1 || true
docker rm martin >/dev/null 2>&1 || true

# 2. Build volume mounts and --sprite args
echo "📦 Building volume mounts and sprite args..."
VOLUME_ARGS=()
SPRITE_ARGS=()

for NAME in "${NAMESPACES[@]}"; do
  for THEME in "${THEMES[@]}"; do
    SRC_DIR="$(pwd)/sprite_assets/${NAME}/${THEME}"
    TARGET_DIR="/sprite_assets/${NAME}_${THEME}"


    VOLUME_ARGS+=(-v "${SRC_DIR}:${TARGET_DIR}")
    SPRITE_ARGS+=(--sprite "${TARGET_DIR}")
  done
done

# 3. Build docker run command
DOCKER_CMD=(
  docker run -d
  --name martin
  --restart unless-stopped
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
sleep 2

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
        curl -sf -o "${OUTPUT}" "${URL}" || echo "⚠️  Failed to download: ${URL}"
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
