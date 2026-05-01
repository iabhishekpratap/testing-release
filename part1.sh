SERVICES=("dir1" "dir2")

CHANGED_FILES=$(git diff --name-only $GIT_PREVIOUS_SUCCESSFUL_COMMIT $GIT_COMMIT)

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

PR_DATA=$(curl -s \
-H "Accept: application/vnd.github+json" \
"https://api.github.com/repos/iabhishekpratap/testing-release/commits/$GIT_COMMIT/pulls")

PR_TITLE=$(echo "$PR_DATA" | jq -r '.[0].title // empty')

echo "Using PR message: $PR_TITLE"

data=$(curl -s https://api.github.com/repos/iabhishekpratap/testing-release/commits/main | jq -r '.sha')
echo "SHA: $data"