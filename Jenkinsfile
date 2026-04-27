pipeline {
    agent any

    environment {
        PR_TITLE = "${env.CHANGE_TITLE}"
    }

    stages {

        stage('Debug') {
            steps {
                echo "Branch: ${env.BRANCH_NAME}"
                echo "PR Title: ${env.CHANGE_TITLE}"
            }
        }

        stage('Run Release') {
            when {
                allOf {
                    branch 'main'
                    expression { return env.CHANGE_TITLE != null }
                }
            }
            steps {
                sh '''
                git fetch --tags
                chmod +x release.sh
                ./release.sh
                '''
            }
        }
    }
}