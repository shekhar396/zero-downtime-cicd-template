pipeline {
    agent any

    options {
        disableConcurrentBuilds()
    }

    environment {
        SERVICE_NAME = 'zero-downtime-demo-go'
        DEMO_DIR = 'zero-downtime-demo-go'
    }

    stages {
        stage('Checkout template') {
            steps {
                checkout scm
            }
        }

        stage('Checkout application') {
            steps {
                dir(env.DEMO_DIR) {
                    git url: 'https://github.com/shekhar396/zero-downtime-demo-go.git'
                }
            }
        }

        stage('Validate') {
            steps {
                sh './scripts/validate-config.sh'
                sh 'find scripts -type f -name "*.sh" -print0 | xargs -0 bash -n'
            }
        }

        stage('Test and build') {
            steps {
                dir(env.DEMO_DIR) {
                    sh 'make test'
                    sh 'make build'
                }
            }
        }

        stage('Deploy') {
            steps {
                sh './scripts/deploy.sh "$SERVICE_NAME" "$DEMO_DIR/bin/$SERVICE_NAME"'
            }
        }

        stage('Verify') {
            steps {
                sh 'curl --fail http://127.0.0.1:8080/health'
                sh './scripts/show-state.sh "$SERVICE_NAME"'
            }
        }
    }
}
