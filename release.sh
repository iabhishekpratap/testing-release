#!/bin/bash

set -e

echo "🔍 Starting release process..."

# -----------------------------
# REQUIRE PR TITLE
# -----------------------------
if [ -z "$PR_TITLE" ]; then
  echo "❌ PR_TITLE not provided"
  exit 1
fi

echo "📌 PR Title: $PR_TITLE"

# -----------------------------
# DETERMINE TYPE FROM PR TITLE
# -----------------------------
if echo "$PR_TITLE" | grep -iq "breaking\|major"; then
  TYPE="major"
elif echo "$PR_TITLE" | grep -iq "minor"; then
  TYPE="minor"
elif echo "$PR_TITLE" | grep -iq "patch"; then
  TYPE="patch"
else
  echo "❌ PR title does not contain version type"
  exit 0
fi

echo "🔧 Release type: $TYPE"

# -----------------------------
# SETUP
# -----------------------------
FOLDERS=("dir1" "dir2")
HEAD_COMMIT=HEAD

git fetch --tags

echo "------------------------------------"

for FOLDER in "${FOLDERS[@]}"; do
  echo "📁 Processing $FOLDER..."

  # -----------------------------
  # GET LAST TAG
  # -----------------------------
  LAST_TAG=$(git tag --list "${FOLDER}-v*" --sort=-v:refname | head -n 1)

  if [ -n "$LAST_TAG" ]; then
    BASE=$LAST_TAG
  else
    BASE=HEAD~1
  fi

  echo "Comparing: $BASE → $HEAD_COMMIT"

  # -----------------------------
  # CHECK FOLDER CHANGES
  # -----------------------------
  if git diff --quiet $BASE $HEAD_COMMIT -- "$FOLDER/"; then
    echo "❌ No changes in $FOLDER"
    echo "------------------------------------"
    continue
  fi

  echo "✅ Changes detected in $FOLDER"

  # -----------------------------
  # CURRENT VERSION
  # -----------------------------
  if [ -z "$LAST_TAG" ]; then
    VERSION="0.0.0"
  else
    VERSION=${LAST_TAG#${FOLDER}-v}
  fi

  IFS='.' read -r MAJOR MINOR PATCH <<< "$VERSION"

  # -----------------------------
  # VERSION BUMP
  # -----------------------------
  if [ "$TYPE" = "major" ]; then
    MAJOR=$((MAJOR+1)); MINOR=0; PATCH=0
  elif [ "$TYPE" = "minor" ]; then
    MINOR=$((MINOR+1)); PATCH=0
  else
    PATCH=$((PATCH+1))
  fi

  NEW_VERSION="$MAJOR.$MINOR.$PATCH"
  NEW_TAG="${FOLDER}-v${NEW_VERSION}"

  # -----------------------------
  # PREVENT DUPLICATE TAG
  # -----------------------------
  if git rev-parse "$NEW_TAG" >/dev/null 2>&1; then
    echo "⚠️ Tag already exists: $NEW_TAG"
    echo "------------------------------------"
    continue
  fi

  # -----------------------------
  # CREATE TAG
  # -----------------------------
  echo "🏷️ Creating tag: $NEW_TAG"

  git tag -a "$NEW_TAG" -m "$PR_TITLE"
  git push origin "$NEW_TAG"

  echo "✅ Released $FOLDER as $NEW_TAG"
  echo "------------------------------------"

done

echo "🎉 Done!"