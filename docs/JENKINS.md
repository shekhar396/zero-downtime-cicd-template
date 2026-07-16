# Jenkins

Jenkins should build the application and call the deployment framework; it should not duplicate blue/green logic.

```text
Checkout
   → Test
   → Build artifact
   → Copy artifact to target VM
   → Call deploy.sh
   → Verify public health endpoint
```

Use `onboard.sh` interactively for first-time server setup or intentional managed configuration changes. Normal Jenkins releases use `deploy.sh`.

## Separation of configuration

- Build-time variables belong to the Jenkins build.
- Runtime variables belong in the server's shared `.env`.
- The runtime `.env` remains on the target VM and is not copied into artifacts.
- Secrets must not be committed or written into build logs.
- Use Jenkins credentials for the SSH key and target host details.
- Generated systemd units inject `PORT` and `ACTIVE_COLOR`.

## Minimal Jenkinsfile

This example checks out both public repositories, builds the Go demo, copies the binary to an already-onboarded VM, deploys it, and verifies the public health endpoint. Configure `deployment-ssh-key` in Jenkins and set `TARGET_HOST` to an approved inventory value.

```groovy
pipeline {
    agent any

    environment {
        SERVICE = 'zero-downtime-demo-go'
        TARGET_HOST = 'deployment-host'
        TEMPLATE_DIR = 'zero-downtime-cicd-template'
        APP_DIR = 'zero-downtime-demo-go'
    }

    stages {
        stage('Checkout') {
            steps {
                dir(env.TEMPLATE_DIR) {
                    git url: 'https://github.com/shekhar396/zero-downtime-cicd-template.git'
                }
                dir(env.APP_DIR) {
                    git url: 'https://github.com/shekhar396/zero-downtime-demo-go.git'
                }
            }
        }

        stage('Test and build') {
            steps {
                dir(env.APP_DIR) {
                    sh 'make test'
                    sh 'make build'
                }
            }
        }

        stage('Deploy') {
            steps {
                sshagent(credentials: ['deployment-ssh-key']) {
                    sh '''
                        set -eu
                        scp "$APP_DIR/bin/$SERVICE" "$TARGET_HOST:/tmp/$SERVICE"
                        ssh "$TARGET_HOST" "cd /opt/zero-downtime-cicd-template && ./scripts/deploy.sh '$SERVICE' '/tmp/$SERVICE'"
                    '''
                }
            }
        }

        stage('Verify') {
            steps {
                sshagent(credentials: ['deployment-ssh-key']) {
                    sh '''
                        ssh "$TARGET_HOST" "curl --fail http://127.0.0.1:8080/health"
                    '''
                }
            }
        }
    }
}
```

The target VM must already contain this repository at `/opt/zero-downtime-cicd-template`, have `config/services.yml` configured, and have completed onboarding. Adjust the repository path through managed Jenkins configuration if your installation uses a different generic location.

Avoid concurrent deployments of the same service. Review a failed deployment before running:

```bash
./scripts/rollback.sh zero-downtime-demo-go --dry-run
./scripts/rollback.sh zero-downtime-demo-go
```
