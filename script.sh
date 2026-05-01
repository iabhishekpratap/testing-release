#!/bin/bash
set -e

SERVICES=("dir1" "dir2")

echo "🔍 Detecting changed files..."

CHANGED_FILES=$(git diff --name-only "$GIT_PREVIOUS_SUCCESSFUL_COMMIT" "$GIT_COMMIT")

echo "Changed files:"
echo "$CHANGED_FILES"

CHANGED_SERVICES=()

for SERVICE in "${SERVICES[@]}"; do
  if echo "$CHANGED_FILES" | grep -q "^services/$SERVICE/"; then
    CHANGED_SERVICES+=("$SERVICE")
  fi
done

if [ ${#CHANGED_SERVICES[@]} -eq 0 ]; then
  echo "✅ No microservice changes detected. Skipping pipeline."
  exit 0
fi

echo "Changed services: ${CHANGED_SERVICES[@]}"

# ================================
# Fetch tags (VERY IMPORTANT)
# ================================
git fetch --tags

# ================================
# Get PR info from GitHub API
# ================================

REPO="iabhishekpratap/testing-release"

PR_DATA=$(curl -s \
  -H "Authorization: token $GITHUB_TOKEN" \
  "https://api.github.com/repos/$REPO/commits/$GIT_COMMIT/pulls")

PR_TITLE=$(echo "$PR_DATA" | jq -r '.[0].title')

# fallback if no PR
if [ "$PR_TITLE" = "null" ]; then
  echo "⚠️ No PR found, fallback to commit message"
  PR_TITLE=$(git log -1 --pretty=%B "$GIT_COMMIT")
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

  TAG=$(git tag --list "${SERVICE}-v*" | sort -V | tail -n 1)

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

  # prevent duplicate tags
  if git rev-parse "$TAG_NAME" >/dev/null 2>&1; then
    echo "⚠️ Tag $TAG_NAME already exists, skipping"
    continue
  fi

  git tag "$TAG_NAME"
done

# ================================
# Push tags
# ================================

git push origin --tags