#!/bin/bash
set -e

SERVICES=("dir1" "dir2")

echo "🔍 Detecting changed files..."

git fetch --all --tags --prune

# avoid unshallow error noise
git fetch --unshallow 2>/dev/null || true

# safe diff handling
if git rev-parse HEAD~1 >/dev/null 2>&1; then
  CHANGED_FILES=$(git diff --name-only HEAD~1 HEAD)
else
  CHANGED_FILES=$(git show --name-only --pretty="" HEAD)
fi

echo "Changed files:"
echo "$CHANGED_FILES"

CHANGED_SERVICES=()

for SERVICE in "${SERVICES[@]}"; do
  if echo "$CHANGED_FILES" | grep -q "^$SERVICE/"; then
    CHANGED_SERVICES+=("$SERVICE")
  fi
done

if [ ${#CHANGED_SERVICES[@]} -eq 0 ]; then
  echo "✅ No microservice changes detected. Skipping pipeline."
  exit 0
fi

echo "Changed services: ${CHANGED_SERVICES[@]}"

# ================================
# Fetch tags
# ================================
git fetch --tags

# ================================
# Get PR info safely
# ================================

REPO="iabhishekpratap/testing-release"

# ensure jq exists
if ! command -v jq >/dev/null 2>&1; then
  echo "⚠️ jq not found, using commit message fallback"
  PR_TITLE=$(git log -1 --pretty=%B HEAD)
else
  PR_DATA=$(curl -s \
    -H "Authorization: token $GITHUB_TOKEN" \
    -H "Accept: application/vnd.github+json" \
    "https://api.github.com/repos/$REPO/commits/$(git rev-parse HEAD)/pulls")

  # check if response is array
  if echo "$PR_DATA" | jq -e 'type == "array"' >/dev/null 2>&1; then
    PR_TITLE=$(echo "$PR_DATA" | jq -r '.[0].title')
  else
    echo "⚠️ PR API failed, fallback to commit message"
    PR_TITLE=$(git log -1 --pretty=%B HEAD)
  fi
fi

# fallback safety
if [ -z "$PR_TITLE" ] || [ "$PR_TITLE" = "null" ]; then
  PR_TITLE=$(git log -1 --pretty=%B HEAD)
fi

echo "Using PR message: $PR_TITLE"

# ================================
# Detect version bump type
# ================================

if echo "$PR_TITLE" | grep -qi "^major"; then
  BUMP_TYPE="major"
elif echo "$PR_TITLE" | grep -qi "^minor"; then
  BUMP_TYPE="minor"
elif echo "$PR_TITLE" | grep -qi "^patch"; then
  BUMP_TYPE="patch"
else
  echo "⛔ Invalid version type → skip"
  exit 0
fi

echo "Detected version type: $BUMP_TYPE"

# ================================
# Functions
# ================================

get_latest_version() {
  SERVICE=$1
  TAG=$(git tag --list "${SERVICE}-v*" --sort=-v:refname | head -n 1)

  if [ -z "$TAG" ]; then
    echo "0.0.0"
  else
    echo "$TAG" | sed "s/${SERVICE}-v//"
  fi
}

bump_version() {
  VERSION=$1
  TYPE=$2

  IFS='.' read -r MAJOR MINOR PATCH <<< "$VERSION"

  case "$TYPE" in
    major)
      MAJOR=$((MAJOR+1)); MINOR=0; PATCH=0 ;;
    minor)
      MINOR=$((MINOR+1)); PATCH=0 ;;
    patch)
      PATCH=$((PATCH+1)) ;;
  esac

  echo "$MAJOR.$MINOR.$PATCH"
}

# ================================
# Tag per service
# ================================

for SERVICE in "${CHANGED_SERVICES[@]}"; do
  echo "🚀 Processing $SERVICE"

  CURRENT_VERSION=$(get_latest_version "$SERVICE")
  echo "Current version: $CURRENT_VERSION"

  NEW_VERSION=$(bump_version "$CURRENT_VERSION" "$BUMP_TYPE")
  echo "New version: $NEW_VERSION"

  TAG_NAME="${SERVICE}-v${NEW_VERSION}"

  # safer duplicate check
  if git tag -l "$TAG_NAME" | grep -q .; then
    echo "⚠️ Tag $TAG_NAME already exists, skipping"
    continue
  fi

  git tag "$TAG_NAME"
done

# ================================
# Push tags
# ================================

git push origin --tags