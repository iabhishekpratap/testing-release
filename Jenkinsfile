pipeline {
    agent any

    triggers {
        githubPush()   
    }

    environment {
        BRANCH_NAME = 'main'
    }

    stages {

        stage('Checkout') {
            steps {
                git branch: "${BRANCH_NAME}", 
                    url: 'https://github.com/iabhishekpratap/testing-release.git'
            }
        }

        stage('Run Script') {
            steps {
                echo "Running pipeline for main branch 🚀"
                sh 'chmod +x script.sh'
                sh './script.sh'
            }
        }
    }

    post {
        success {
            echo 'Build Success ✅'
        }
        failure {
            echo 'Build Failed ❌'
        }
    }
}