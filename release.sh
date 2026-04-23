#!/bin/bash

set -e

echo "🔍 Detecting changes and commit type..."

FOLDERS=("dir1" "dir2")

HEAD_COMMIT=HEAD

echo "------------------------------------"

for FOLDER in "${FOLDERS[@]}"; do
  echo "📁 Processing $FOLDER..."

  # -----------------------------
  # GET LAST TAG PER FOLDER (FIXED)
  # -----------------------------
  LAST_TAG=$(git tag --list "${FOLDER}-v*" --sort=-v:refname | head -n 1)

  if [ -n "$LAST_TAG" ]; then
    BASE=$LAST_TAG
    echo "Using last tag for $FOLDER: $BASE"
  else
    BASE=HEAD~1
    echo "No previous tag for $FOLDER → using HEAD~1"
  fi

  echo "Comparing: $BASE → $HEAD_COMMIT"

  # -----------------------------
  # CHECK FOLDER CONTENT CHANGE
  # -----------------------------
  if git diff --quiet $BASE $HEAD_COMMIT -- "$FOLDER/"; then
    echo "❌ No changes in $FOLDER"
    echo "------------------------------------"
    continue
  fi

  echo "✅ Changes detected in $FOLDER"

  # -----------------------------
  # GET COMMITS FOR THIS FOLDER
  # -----------------------------
  COMMITS=$(git log $BASE..$HEAD_COMMIT --pretty=format:"%s" -- "$FOLDER/")

  echo "📝 Commits:"
  echo "$COMMITS"

  # -----------------------------
  # DETERMINE VERSION TYPE
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
    echo "❌ No valid release commit for $FOLDER"
    echo "------------------------------------"
    continue
  fi

  echo "🔧 Release type: $TYPE"

  # -----------------------------
  # CURRENT VERSION
  # -----------------------------
  if [ -z "$LAST_TAG" ]; then
    VERSION="0.0.0"
  else
    VERSION=${LAST_TAG#${FOLDER}-v}
  fi

  echo "📌 Current version: $VERSION"

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
  # CREATE TAG + PUSH
  # -----------------------------
  echo "🏷️ Creating tag: $NEW_TAG"

  git tag -a $NEW_TAG -m "$COMMITS"
  git push origin $NEW_TAG

  # -----------------------------
  # GITHUB RELEASE (OPTIONAL)
  # -----------------------------
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