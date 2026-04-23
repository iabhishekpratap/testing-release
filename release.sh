#!/bin/bash

set -e

echo "🔍 Detecting changes and commit type..."

FOLDERS=("dir1" "dir2")

# -----------------------------
# DETERMINE BASE COMMIT (FIXED)
# -----------------------------
LAST_GLOBAL_TAG=$(git describe --tags --abbrev=0 2>/dev/null || echo "")

if [ -n "$LAST_GLOBAL_TAG" ]; then
  BASE=$LAST_GLOBAL_TAG
  echo "Using last tag as base: $BASE"
else
  echo "No previous tag found → using HEAD~1"
  BASE=HEAD~1
fi

HEAD_COMMIT=HEAD

echo "Comparing: $BASE → $HEAD_COMMIT"
echo "------------------------------------"

# -----------------------------
# GET COMMIT MESSAGES
# -----------------------------
COMMITS=$(git log $BASE..$HEAD_COMMIT --pretty=format:"%s")

echo "📝 Commit messages:"
echo "$COMMITS"
echo "------------------------------------"

# -----------------------------
# DETERMINE VERSION TYPE (FIXED)
# -----------------------------
if echo "$COMMITS" | grep -q "BREAKING CHANGE\|!:"; then
  TYPE="major"
elif echo "$COMMITS" | grep -q "^major"; then
  TYPE="major"
elif echo "$COMMITS" | grep -q "^minor"; then
  TYPE="minor"
elif echo "$COMMITS" | grep -q "^patch"; then
  TYPE="patch"
else
  echo "❌ No valid release commit found (major/minor/patch). Exiting."
  exit 0
fi

echo "🔧 Release type: $TYPE"
echo "------------------------------------"

# -----------------------------
# PROCESS EACH FOLDER
# -----------------------------
for FOLDER in "${FOLDERS[@]}"; do
  echo "Checking $FOLDER..."

  # Check if folder content changed
  if git diff --quiet $BASE $HEAD_COMMIT -- "$FOLDER/"; then
    echo "❌ No changes in $FOLDER"
    continue
  fi

  echo "✅ Changes detected in $FOLDER"

  # Get last tag for this service
  LAST_TAG=$(git tag --list "${FOLDER}-v*" --sort=-v:refname | head -n 1)

  if [ -z "$LAST_TAG" ]; then
    VERSION="0.0.0"
  else
    VERSION=${LAST_TAG#${FOLDER}-v}
  fi

  echo "📌 Current version: $VERSION"

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
  NEW_TAG="${FOLDER}-v${NEW_VERSION}"

  # Prevent duplicate tag
  if git rev-parse "$NEW_TAG" >/dev/null 2>&1; then
    echo "⚠️ Tag already exists: $NEW_TAG"
    continue
  fi

  echo "🏷️ Creating tag: $NEW_TAG"

  git tag -a $NEW_TAG -m "$COMMITS"
  git push origin $NEW_TAG

  # Optional GitHub release
  if command -v gh &> /dev/null; then
    gh release create $NEW_TAG \
      --title "$NEW_TAG" \
      --notes "$COMMITS"
  else
    echo "⚠️ gh CLI not installed, skipping GitHub release"
  fi

  echo "✅ Released $FOLDER as $NEW_TAG"
  echo "------------------------------------"

done

echo "🎉 Done!"