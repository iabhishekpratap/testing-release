#!/bin/bash

set -e

echo "🔍 Detecting changed services..."

# Detect changes
CHANGED_FILES=$(git diff --name-only origin/main...HEAD 2>/dev/null || git diff --name-only HEAD~1 HEAD)

echo "Changed files:"
echo "$CHANGED_FILES"
echo "------------------------------------"

SERVICES=()
ALL_SERVICES=("dir1" "dir2")

# Detect changed services
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

# Process each service
for SERVICE in "${SERVICES[@]}"; do
  echo "🚀 Processing $SERVICE..."

  LAST_TAG=$(git tag --list "${SERVICE}-v*" --sort=-v:refname | head -n 1)

  if [ -z "$LAST_TAG" ]; then
    VERSION="0.0.0"
  else
    VERSION=${LAST_TAG#${SERVICE}-v}
  fi

  echo "📌 Current version: $VERSION"

  # Ask version type
  echo ""
  echo "Select version bump for $SERVICE:"
  echo "1) Major"
  echo "2) Minor"
  echo "3) Patch"
  read -p "Enter choice (1/2/3): " CHOICE

  case $CHOICE in
    1) TYPE="major" ;;
    2) TYPE="minor" ;;
    3) TYPE="patch" ;;
    *) echo "❌ Invalid choice"; exit 1 ;;
  esac

  echo "🔧 Selected: $TYPE"

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

  # Avoid duplicate
  if git rev-parse "$NEW_TAG" >/dev/null 2>&1; then
    echo "⚠️ Tag already exists: $NEW_TAG"
    continue
  fi

  echo "🏷️ New tag: $NEW_TAG"

  # Ask release notes
  echo ""
  read -p "📝 Enter release notes: " NOTES

  # Create tag
  git tag -a $NEW_TAG -m "$NOTES"
  git push origin $NEW_TAG

  # Create GitHub release (optional)
  if command -v gh &> /dev/null; then
    gh release create $NEW_TAG \
      --title "$NEW_TAG" \
      --notes "$NOTES"
  else
    echo "⚠️ gh CLI not installed, skipping GitHub release"
  fi

  echo "✅ Released $SERVICE as $NEW_TAG"
  echo "------------------------------------"

done

echo "🎉 All done!"