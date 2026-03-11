pipeline {
    agent any

    parameters {
        string(
            name: 'TESTRAIL_CASE_ID',
            description: 'TestRail case ID, e.g. C738972'
        )
        string(
            name: 'GITHUB_REPO',
            description: 'Target GitHub repository (org/repo)'
        )
        choice(
            name: 'GEMINI_MODEL',
            choices: ['gemini-2.5-flash-lite', 'gemini-2.5-flash'],
            description: 'Gemini model to use'
        )
    }

    environment {
        GEMINI_API_KEY   = credentials('gemini-api-key')
        GITHUB_TOKEN     = credentials('github-token')
        TESTRAIL_API_KEY = credentials('testrail-api-key')
    }

    stages {
        stage('Validate') {
            steps {
                script {
                    if (!params.TESTRAIL_CASE_ID?.trim()) {
                        error("TESTRAIL_CASE_ID is required")
                    }
                }
            }
        }

        stage('Build Agent Image') {
            steps {
                sh 'docker build -t gemini-qa-agent:latest .'
            }
        }

        stage('Run Agent') {
            steps {
                sh """
                    docker run --rm \\
                      --shm-size=2gb \\
                      -e GEMINI_API_KEY=${GEMINI_API_KEY} \\
                      -e GEMINI_MODEL=${params.GEMINI_MODEL} \\
                      -e GITHUB_TOKEN=${GITHUB_TOKEN} \\
                      -e GH_TOKEN=${GITHUB_TOKEN} \\
                      -e GITHUB_REPO=${params.GITHUB_REPO} \\
                      -e GIT_USER_NAME="Gemini Agent" \\
                      -e GIT_USER_EMAIL="gemini@ci.local" \\
                      -e TESTRAIL_URL=${TESTRAIL_URL} \\
                      -e TESTRAIL_USERNAME=${TESTRAIL_USERNAME} \\
                      -e TESTRAIL_API_KEY=${TESTRAIL_API_KEY} \\
                      -e TESTRAIL_PROJECT_ID=${TESTRAIL_PROJECT_ID} \\
                      -e TESTRAIL_CASE_ID=${params.TESTRAIL_CASE_ID} \\
                      gemini-qa-agent:latest
                """
            }
        }
    }

    post {
        success {
            echo "Agent completed. PR created in ${params.GITHUB_REPO}"
        }
        failure {
            echo "Agent failed. Check logs above."
        }
        always {
            sh 'docker image prune -f || true'
        }
    }
}
