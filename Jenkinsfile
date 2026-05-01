pipeline {
    agent any

    environment {
        GITHUB_TOKEN = credentials('github') // add in Jenkins credentials
    }

    stages {
        stage('Checkout') {
            steps {
                checkout scm
            }
        }

        stage('Run Script') {
            steps {
                sh 'chmod +x script.sh'
                sh './script.sh'
            }
        }
    }
}