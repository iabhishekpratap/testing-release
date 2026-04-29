# -----------------------------
# GET PR NUMBER FROM COMMIT
# -----------------------------
PR_NUMBER=$(git log -1 --pretty=%B | grep -oE '#[0-9]+' | tr -d '#')

if [ -z "$PR_NUMBER" ]; then
  echo "⚠️ No PR found (direct push?), skipping..."
  exit 0
fi

echo "🔗 PR Number: $PR_NUMBER"

# -----------------------------
# FETCH PR TITLE
# -----------------------------
PR_TITLE=$(curl -s \
  -H "Authorization: token $GITHUB_TOKEN" \
  https://api.github.com/repos/iabhishekpratap/testing-release/pulls/$PR_NUMBER \
  | jq -r '.title')

if [ -z "$PR_TITLE" ] || [ "$PR_TITLE" = "null" ]; then
  echo "❌ Failed to fetch PR title"
  exit 1
fi

echo "📌 PR Title: $PR_TITLE"

# -----------------------------
# DETERMINE VERSION TYPE
# -----------------------------
if [[ "$PR_TITLE" == *"major"* ]]; then
  TYPE="major"
elif [[ "$PR_TITLE" == *"minor"* ]]; then
  TYPE="minor"
elif [[ "$PR_TITLE" == *"patch"* ]]; then
  TYPE="patch"
else
  echo "⚠️ No version keyword → skipping"
  exit 0
fi

echo "🚀 Version bump: $TYPE"