pipeline {
    agent any

    stages {
        stage('Checkout') {
            steps {
                checkout scm
            }
        }

        stage('Debug Commits') {
            steps {
                sh '''
                    echo "📌 GIT_COMMIT: $GIT_COMMIT"
                    echo "📌 GIT_PREVIOUS_SUCCESSFUL_COMMIT: $GIT_PREVIOUS_SUCCESSFUL_COMMIT"

                    echo "🔍 Git HEAD:"
                    git log --oneline -5
                '''
            }
        }

        stage('Test Diff') {
            steps {
                sh '''
                    set -e

                    # Fix shallow clone
                    git fetch --unshallow || true

                    CURRENT=${GIT_COMMIT:-$(git rev-parse HEAD)}
                    PREVIOUS=${GIT_PREVIOUS_SUCCESSFUL_COMMIT:-$(git rev-parse HEAD~1)}

                    echo "📌 Comparing:"
                    echo "OLD: $PREVIOUS"
                    echo "NEW: $CURRENT"

                    echo "📂 Changed Files:"
                    git diff --name-only $PREVIOUS $CURRENT

                    echo "🔍 Checking auth service..."
                    if git diff --name-only $PREVIOUS $CURRENT | grep -q "^services/auth/"; then
                        echo "✅ auth changed"
                    else
                        echo "❌ auth NOT changed"
                    fi
                '''
            }
        }
    }
}