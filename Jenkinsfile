pipeline {
    agent any

    options {
        disableConcurrentBuilds()
    }

    parameters {
        string(name: 'SERVICE_NAME', defaultValue: 'billing-api', description: 'Registered service name from config/services.yml')
        string(name: 'ARTIFACT_PATH', defaultValue: 'examples/mock-artifact', description: 'Path to artifact directory or file available in the workspace')
        choice(name: 'DEPLOY_ENV', choices: ['staging', 'production'], description: 'Deployment environment label for operator context')
        booleanParam(name: 'DRY_RUN', defaultValue: true, description: 'Run validation and deploy dry-run only')
        booleanParam(name: 'AUTO_APPROVE', defaultValue: false, description: 'Skip manual production approval when explicitly enabled')
    }

    environment {
        SERVICE_NAME = "${params.SERVICE_NAME}"
        ARTIFACT_PATH = "${params.ARTIFACT_PATH}"
        DEPLOY_ENV = "${params.DEPLOY_ENV}"
    }

    stages {
        stage('Checkout') { steps { checkout scm } }
        stage('Validate Config') { steps { sh 'make validate-config' } }
        stage('Validate Shell Scripts') { steps { sh 'make lint-shell' } }
        stage('Create/Prepare Artifact') {
            steps {
                sh '''
                    set -eu
                    if [ ! -e "$ARTIFACT_PATH" ]; then
                      echo "Artifact path not found: $ARTIFACT_PATH" >&2
                      exit 1
                    fi
                    echo "Using artifact path: $ARTIFACT_PATH"
                '''
            }
        }
        stage('Deploy Dry Run') {
            steps { sh './scripts/deploy.sh "$SERVICE_NAME" "$ARTIFACT_PATH" --dry-run' }
        }
        stage('Manual Approval for Production') {
            when { expression { params.DEPLOY_ENV == 'production' && !params.DRY_RUN && !params.AUTO_APPROVE } }
            steps { input message: "Approve production deployment for ${params.SERVICE_NAME}?", ok: 'Deploy' }
        }
        stage('Deploy') {
            when { expression { !params.DRY_RUN } }
            steps { sh './scripts/deploy.sh "$SERVICE_NAME" "$ARTIFACT_PATH"' }
        }
        stage('Post Deployment State') {
            steps {
                sh './scripts/show-state.sh "$SERVICE_NAME"'
                sh './scripts/list-releases.sh "$SERVICE_NAME"'
            }
        }
    }

    post {
        failure {
            echo "Deployment failed for ${params.SERVICE_NAME}. Review logs and run rollback manually if required:"
            echo "  ./scripts/rollback.sh ${params.SERVICE_NAME} --dry-run"
            echo "  ./scripts/rollback.sh ${params.SERVICE_NAME}"
        }
        success {
            echo "Pipeline completed for ${params.SERVICE_NAME}. DRY_RUN=${params.DRY_RUN} DEPLOY_ENV=${params.DEPLOY_ENV}"
        }
    }
}
