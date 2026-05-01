#!/bin/bash

set -e

echo "🚀 Starting Release प्रक्रिया..."

# Example services folder
SERVICES=("auth" "payment" "user" "order")

# -----------------------------
# VALIDATE REQUIRED VARS
# -----------------------------
if [ -z "$GITHUB_TOKEN" ]; then
  echo "❌ GITHUB_TOKEN not set"
  exit 1
fi

if [ -z "$GIT_COMMIT" ]; then
  echo "❌ GIT_COMMIT not set"
  exit 1
fi

echo "📌 Commit SHA: $GIT_COMMIT"

# -----------------------------
# FETCH PR DATA FROM COMMIT
# -----------------------------
echo "🔍 Fetching PR linked to commit..."

PR_DATA=$(curl -s \
  -H "Authorization: token $GITHUB_TOKEN" \
  -H "Accept: application/vnd.github.groot-preview+json" \
  https://api.github.com/repos/$REPO_OWNER/$REPO_NAME/commits/$GIT_COMMIT/pulls)

PR_TITLE=$(echo "$PR_DATA" | jq -r '.[0].title')

if [ "$PR_TITLE" == "null" ] || [ -z "$PR_TITLE" ]; then
  echo "❌ No PR found for this commit"
  exit 1
fi

echo "📌 PR Title: $PR_TITLE"

# -----------------------------
# DETERMINE VERSION TYPE
# -----------------------------
if [[ "$PR_TITLE" == *major* ]]; then
  VERSION_TYPE="major"
elif [[ "$PR_TITLE" == *minor* ]]; then
  VERSION_TYPE="minor"
elif [[ "$PR_TITLE" == *patch* ]]; then
  VERSION_TYPE="patch"
else
  echo "⚠️ No version keyword found → skipping release"
  exit 0
fi

echo "🔖 Version type: $VERSION_TYPE"

# -----------------------------
# GET CHANGED FILES
# -----------------------------
echo "📂 Detecting changed files..."

CHANGED_FILES=$(git diff --name-only HEAD~1 HEAD)

if [ -z "$CHANGED_FILES" ]; then
  echo "⚠️ No changes detected"
  exit 0
fi

echo "$CHANGED_FILES"

# -----------------------------
# DETECT AFFECTED SERVICES
# -----------------------------
CHANGED_SERVICES=()

for SERVICE in "${SERVICES[@]}"; do
  if echo "$CHANGED_FILES" | grep -q "^services/$SERVICE/"; then
    CHANGED_SERVICES+=("$SERVICE")
  fi
done

if [ ${#CHANGED_SERVICES[@]} -eq 0 ]; then
  echo "⚠️ No microservice changes detected → skipping"
  exit 0
fi

echo "✅ Changed services: ${CHANGED_SERVICES[*]}"

# -----------------------------
# BUMP VERSION FUNCTION
# -----------------------------
bump_version() {
  local SERVICE=$1

  echo "🔄 Processing service: $SERVICE"

  LATEST_TAG=$(git tag | grep "^${SERVICE}-v" | sort -V | tail -n 1)

  if [ -z "$LATEST_TAG" ]; then
    echo "⚡ First release for $SERVICE"
    NEW_VERSION="1.0.0"
  else
    VERSION=$(echo "$LATEST_TAG" | sed "s/${SERVICE}-v//")
    IFS='.' read -r MAJOR MINOR PATCH <<< "$VERSION"

    if [ "$VERSION_TYPE" = "major" ]; then
      MAJOR=$((MAJOR+1)); MINOR=0; PATCH=0
    elif [ "$VERSION_TYPE" = "minor" ]; then
      MINOR=$((MINOR+1)); PATCH=0
    else
      PATCH=$((PATCH+1))
    fi

    NEW_VERSION="$MAJOR.$MINOR.$PATCH"
  fi

  NEW_TAG="${SERVICE}-v${NEW_VERSION}"

  echo "🏷️ Creating tag: $NEW_TAG"

  git tag "$NEW_TAG"
  git push origin "$NEW_TAG"

  echo "✅ Released $NEW_TAG"
}

# -----------------------------
# PROCESS EACH SERVICE
# -----------------------------
for SERVICE in "${CHANGED_SERVICES[@]}"; do
  bump_version "$SERVICE"
done

echo "🎉 Release process completed!"