#!/bin/bash

set -e

echo "🔍 Detecting changed services..."

# Get changed files (works in CI + local)
CHANGED_FILES=$(git diff --name-only origin/main...HEAD 2>/dev/null || git diff --name-only HEAD~1 HEAD)

echo "Changed files:"
echo "$CHANGED_FILES"
echo "------------------------------------"

SERVICES=()

# Define your microservices here
ALL_SERVICES=("dir1" "dir2")

# Detect changes per folder
for SERVICE in "${ALL_SERVICES[@]}"; do
  if echo "$CHANGED_FILES" | grep -q "^${SERVICE}/"; then
    echo "✅ Changes detected in $SERVICE"
    SERVICES+=("$SERVICE")
  else
    echo "❌ No changes in $SERVICE"
  fi
done

if [ ${#SERVICES[@]} -eq 0 ]; then
  echo "❌ No relevant service changes detected. Exiting."
  exit 0
fi

echo "------------------------------------"

# Process each changed service
for SERVICE in "${SERVICES[@]}"; do
  echo "🚀 Processing $SERVICE..."

  # Get last tag for this service
  LAST_TAG=$(git tag --list "${SERVICE}-v*" --sort=-v:refname | head -n 1)

  # -------------------------------
  # FIRST RELEASE
  # -------------------------------
  if [ -z "$LAST_TAG" ]; then
    echo "⚠️ No previous tag found for $SERVICE. Creating initial release 1.0.0"

    NEW_VERSION="1.0.0"
    NEW_TAG="${SERVICE}-v${NEW_VERSION}"

    if git rev-parse "$NEW_TAG" >/dev/null 2>&1; then
      echo "⚠️ Tag $NEW_TAG already exists, skipping..."
      continue
    fi

    echo "🏷️ Creating initial tag: $NEW_TAG"
    git tag $NEW_TAG
    git push origin $NEW_TAG

    if command -v gh &> /dev/null; then
      gh release create $NEW_TAG \
        --title "$NEW_TAG" \
        --notes "Initial release for $SERVICE"
    else
      echo "⚠️ gh CLI not installed, skipping GitHub release"
    fi

    echo "✅ Initial release done for $SERVICE"
    echo "------------------------------------"
    continue
  fi

  # -------------------------------
  # NORMAL RELEASE FLOW
  # -------------------------------
  VERSION=${LAST_TAG#${SERVICE}-v}
  echo "📌 Current version: $VERSION"

  # Get commits since last tag
  COMMITS=$(git log ${LAST_TAG}..HEAD --pretty=format:"%s")

  echo "📝 Commits since last release:"
  echo "$COMMITS"
  echo "------------------------------------"

  # Determine version bump
  if echo "$COMMITS" | grep -q "BREAKING CHANGE\|!:"; then
    TYPE="major"
  elif echo "$COMMITS" | grep -q "^feat"; then
    TYPE="minor"
  elif echo "$COMMITS" | grep -q "^fix"; then
    TYPE="patch"
  else
    TYPE="patch"
  fi

  echo "🔧 Version bump type: $TYPE"

  # Split version
  IFS='.' read -r MAJOR MINOR PATCH <<< "$VERSION"

  if [ "$TYPE" = "major" ]; then
    MAJOR=$((MAJOR+1)); MINOR=0; PATCH=0
  elif [ "$TYPE" = "minor" ]; then
    MINOR=$((MINOR+1)); PATCH=0
  else
    PATCH=$((PATCH+1))
  fi

  NEW_VERSION="$MAJOR.$MINOR.$PATCH"
  NEW_TAG="${SERVICE}-v${NEW_VERSION}"

  # Prevent duplicate tag
  if git rev-parse "$NEW_TAG" >/dev/null 2>&1; then
    echo "⚠️ Tag $NEW_TAG already exists, skipping..."
    continue
  fi

  echo "🏷️ Creating tag: $NEW_TAG"
  git tag $NEW_TAG
  git push origin $NEW_TAG

  # Optional GitHub release
  if command -v gh &> /dev/null; then
    echo "📦 Creating GitHub release..."
    gh release create $NEW_TAG \
      --title "$NEW_TAG" \
      --notes "Release for $SERVICE version $NEW_VERSION"
  else
    echo "⚠️ gh CLI not installed, skipping GitHub release"
  fi

  echo "✅ Done for $SERVICE"
  echo "------------------------------------"

done

echo "🎉 All done!"