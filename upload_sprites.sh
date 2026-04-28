#!/bin/bash

set -e

ENV="${1:?Usage: bash upload_sprites.sh <env>  (env = staging | prod)}"
[[ "$ENV" =~ ^(staging|prod)$ ]] || { echo "❌ env must be staging|prod"; exit 1; }

NAMESPACES=(AtB Troms NFK FRAM)

get_bucket() {
  local ns="$1" env="$2"
  case "$env/$ns" in
    prod/AtB)      echo "atb-mobility-platform--shared-assets" ;;
    prod/Troms)    echo "troms-prod--shared-assets" ;;
    prod/NFK)      echo "nfk-prod--shared-assets" ;;
    prod/FRAM)     echo "fram-prod-a7850--shared-assets" ;;
    staging/AtB)   echo "atb-mobility-platform-staging--shared-assets" ;;
    staging/Troms) echo "troms-staging--shared-assets" ;;
    staging/NFK)   echo "nfk-staging--shared-assets" ;;
    staging/FRAM)  echo "fram-staging--shared-assets" ;;
    *) echo "" ;;
  esac
}

MANIFEST="uploads.md"
OUT_BASE="./generated_sprites"

# --- pre-flight ---
gcloud auth print-access-token >/dev/null 2>&1 || \
  { echo "❌ gcloud not authenticated. Run: gcloud auth application-default login"; exit 1; }

[[ -z "$(git status --porcelain)" ]] || \
  { echo "❌ working tree dirty — commit or stash first (manifest and tag must point at a real commit)"; exit 1; }

git fetch origin --quiet
BRANCH="$(git rev-parse --abbrev-ref HEAD)"
git merge-base --is-ancestor HEAD "origin/$BRANCH" 2>/dev/null || \
  { echo "❌ HEAD not pushed to origin/$BRANCH — push first"; exit 1; }

COMMIT="$(git rev-parse HEAD)"
SHORT_SHA="$(git rev-parse --short HEAD)"
UPLOADER="$(git config user.email)"
TIMESTAMP="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

# --- determine next version (auto-bump per env from manifest) ---
LAST_VERSION=""
if [[ -f "$MANIFEST" ]]; then
  LAST_VERSION=$(awk -F'|' -v env="$ENV" '
    {
      gsub(/^ +| +$/, "", $3)
      gsub(/^ +| +$/, "", $4)
      if ($3 == env && $4 ~ /^v[0-9]+$/) v=$4
    }
    END { if (v) print v }
  ' "$MANIFEST")
fi
if [[ -z "$LAST_VERSION" ]]; then
  echo "❌ no prior $ENV entry found in $MANIFEST"
  echo "   Seed it with a baseline row, e.g.:"
  echo "   | $(date -u +%Y-%m-%dT%H:%M:%SZ) | $ENV | v4 | 0000000 | seed |"
  exit 1
fi
NEXT_NUM=$(( ${LAST_VERSION#v} + 1 ))
NEXT_VERSION="v${NEXT_NUM}"
echo "🆕 $ENV: $LAST_VERSION → $NEXT_VERSION"

# --- validate generated_sprites are present ---
for NAME in "${NAMESPACES[@]}"; do
  [[ -d "$OUT_BASE/$NAME" ]] || { echo "❌ $OUT_BASE/$NAME missing — run generate_sprites.sh first"; exit 1; }
done

# --- upload all tenants ---
echo "☁️  Uploading to $ENV ($NEXT_VERSION)..."
for NAME in "${NAMESPACES[@]}"; do
  BUCKET="$(get_bucket "$NAME" "$ENV")"
  DEST="gs://${BUCKET}/map-assets/${NEXT_VERSION}/"
  echo "  ➤ $NAME → $DEST"
  gcloud storage cp "${OUT_BASE}/${NAME}/"*.{png,json} "$DEST"
done

# --- append manifest row ---
echo "| $TIMESTAMP | $ENV | $NEXT_VERSION | $SHORT_SHA | $UPLOADER |" >> "$MANIFEST"

# --- commit + tag + push ---
git add "$MANIFEST"
git commit -m "chore: upload sprites to $ENV ($NEXT_VERSION)"
git tag -a "upload/$ENV/$NEXT_VERSION" \
  -m "Uploaded sprites to $ENV $NEXT_VERSION at $TIMESTAMP (commit $SHORT_SHA, by $UPLOADER)"
git push --follow-tags

echo "✅ done — tag: upload/$ENV/$NEXT_VERSION"
