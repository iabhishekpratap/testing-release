pipeline {
    agent any

    environment {
        GITHUB_TOKEN = credentials('github-token-id')
    }

    stages {

        stage('Get PR Title') {
            when {
                branch 'main'
            }
            steps {
                script {
                    // Extract owner/repo dynamically
                    def repo = env.GIT_URL.replaceFirst(/.*github.com[/:]/, '').replace('.git','')

                    def prTitle = sh(
                        script: """
                        curl -s \
                          -H "Authorization: token $GITHUB_TOKEN" \
                          -H "Accept: application/vnd.github.groot-preview+json" \
                          https://api.github.com/repos/${repo}/commits/${GIT_COMMIT}/pulls \
                          | jq -r '.[0].title'
                        """,
                        returnStdout: true
                    ).trim()

                    env.PR_TITLE = prTitle
                }
            }
        }

        stage('Debug') {
            steps {
                echo "PR Title: ${env.PR_TITLE}"
            }
        }

        stage('Run Release') {
            when {
                expression { return env.PR_TITLE != null && env.PR_TITLE != "" }
            }
            steps {
                sh '''
                export PR_TITLE="$PR_TITLE"
                chmod +x release.sh
                ./release.sh
                '''
            }
        }
    }
}