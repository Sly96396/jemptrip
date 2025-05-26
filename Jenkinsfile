pipeline {
    agent any

    environment {
        // GitHub configuration
        GITHUB_REPO = 'Sly96396/jemptrip'  // Your private GitHub repo
        GITHUB_BRANCH = 'main'                     // Branch to build
        GITHUB_CREDENTIALS_ID = 'github-creds'     // Jenkins credentials ID for GitHub
        
        // Docker image configuration
        DOCKER_IMAGE_NAME = 'jemptrip'      // Name for your Docker image
        DOCKERFILE_PATH = 'Dockerfile'            // Path to your Dockerfile
        
        // Harbor registry configuration
        HARBOR_REGISTRY = 'harbor.ramola.top'  // Your Harbor registry URL
        HARBOR_PROJECT = 'img'            // Harbor project name
        DOCKER_CREDENTIALS_ID = 'harbor-creds'     // Jenkins credentials ID for Harbor
        ARGOCD_APP_NAME = 'jemptrip'
        ARGOCD_PROJECT = 'default'
        ARGOCD_SERVER = 'argocd.ramola.top'
        ARGOCD_USERNAME = 'admin'
        ARGOCD_PASSWORD = 'XeMRMCQ6phpPzclF'
        GIT_REPO_URL = 'https://github.com/Sly96396/jemptrip.git'
        GIT_REVISION = 'HEAD'
        DEST_NAMESPACE = 'jemptrip'
        DEST_SERVER = 'https://kubernetes.default.svc'

        BUILD_NUMBER = "0.0.1"
    }

    options {
        timeout(time: 30, unit: 'MINUTES')
        buildDiscarder(logRotator(numToKeepStr: '10'))
    }

    stages {
        stage('Checkout from Private GitHub') {
            steps {
                script {
                    // Verify GitHub credentials exist
                    def githubCreds = credentials("${env.GITHUB_CREDENTIALS_ID}")
                    
                    // Checkout code from private GitHub repository with authentication
                    checkout([
                        $class: 'GitSCM',
                        branches: [[name: "*/${env.GITHUB_BRANCH}"]],
                        extensions: [
                            [$class: 'CloneOption', depth: 1, noTags: false, reference: '', shallow: true],
                            [$class: 'RelativeTargetDirectory', relativeTargetDir: 'source']
                        ],
                        userRemoteConfigs: [[
                            credentialsId: env.GITHUB_CREDENTIALS_ID,
                            url: "https://github.com/${env.GITHUB_REPO}.git"
                        ]]
                    ])
                    
                    // Get the current Git commit hash for tagging
                    COMMIT_HASH = sh(returnStdout: true, script: 'git rev-parse --short HEAD').trim()
                    BUILD_TIMESTAMP = new Date().format('yyyyMMdd-HHmmss', TimeZone.getTimeZone('UTC'))
                    GIT_REPO_NAME = sh(returnStdout: true, script: 'basename -s .git `git config --get remote.origin.url`').trim()
                    
                    echo "Checked out commit: ${COMMIT_HASH}"
                    echo "Build timestamp: ${BUILD_TIMESTAMP}"
                    echo "Repository name: ${GIT_REPO_NAME}"
                }
            }
        }
        

       stage('Build & Update Image in GitOps') {
    steps {
        script {
            // Verify Docker credentials exist
            def harborCreds = credentials("${env.DOCKER_CREDENTIALS_ID}")
            
            // Build and push image to Harbor
            docker.withRegistry("https://${env.HARBOR_REGISTRY}", env.DOCKER_CREDENTIALS_ID) {
                def customImage = docker.build(
                    "${env.HARBOR_PROJECT}/${env.DOCKER_IMAGE_NAME}:${env.BUILD_NUMBER}",
                    "--no-cache -f ${env.DOCKERFILE_PATH} ./"
                )
                
                // Push with multiple tags
                customImage.push("${env.BUILD_NUMBER}")
                customImage.push("commit-${COMMIT_HASH}")
                customImage.push("${BUILD_TIMESTAMP}")

                // Optional: push 'latest' tag if on main branch
                if (env.GITHUB_BRANCH == 'main') {
                    docker.image("${env.HARBOR_PROJECT}/${env.DOCKER_IMAGE_NAME}:${env.BUILD_NUMBER}")
                          .push("latest")
                }
            }

        }
    }
}
        
        stage('Cleanup Docker Environment') {
            steps {
                script {
                    // Clean up Docker resources to save disk space
                    sh 'docker system prune -f --filter "until=24h"'
                }
            }
        }

        stage('Login to ArgoCD') {
    steps {
        script {
            withCredentials([
                usernamePassword(credentialsId: 'github-creds', usernameVariable: 'GIT_USER', passwordVariable: 'GIT_PASS')
            ]) {
                sh """
                    argocd login ${ARGOCD_SERVER} \\
                        --username ${ARGOCD_USERNAME} \\
                        --password ${ARGOCD_PASSWORD} \\
                        --grpc-web

                    if argocd repo list | grep -q '${GIT_REPO_URL}'; then
                        echo "Repo already registered in Argo CD"
                    else
                        argocd repo add ${GIT_REPO_URL} \\
                            --username \$GIT_USER \\
                            --password \$GIT_PASS \\
                            --name ${ARGOCD_APP_NAME} \\
                            --grpc-web
                        echo "Repo added."
                    fi
                """
            }
        }
    }
}

stage('Create ArgoCD Application') {
    steps {
        script {
            echo "Creating Argo CD application: ${ARGOCD_APP_NAME}"
            sh """
                argocd app create ${ARGOCD_APP_NAME} \\
                    --project ${ARGOCD_PROJECT} \\
                    --repo ${GIT_REPO_URL} \\
                    --revision ${GIT_REVISION} \\
                    --path . \\
                    --dest-server ${DEST_SERVER} \\
                    --dest-namespace ${DEST_NAMESPACE} \\
                    --sync-policy automated \\
                    --self-heal \\
                    --upsert
            """
        }
    }
}

stage('Modify Manifest and Sync ArgoCD (No Push)') {
    steps {
        script {
            dir('gitops') {
                // Clone the repo (without modifying Git history)
                git branch: "${GITHUB_BRANCH}", credentialsId: "${GITHUB_CREDENTIALS_ID}", url: "${GIT_REPO_URL}"

                // Modify the manifest file (fail if sed fails)
                sh """
                    sed -i 's|image: ${HARBOR_REGISTRY}/${HARBOR_PROJECT}/${DOCKER_IMAGE_NAME}:.*|image: ${HARBOR_REGISTRY}/${HARBOR_PROJECT}/${DOCKER_IMAGE_NAME}:${BUILD_NUMBER}|' kube.yml || exit 1
                """

                // Sync ArgoCD using local manifest (no Git push)
                sh """
                    argocd login ${ARGOCD_SERVER} \\
                        --username ${ARGOCD_USERNAME} \\
                        --password ${ARGOCD_PASSWORD} \\
                        --grpc-web \\
                        --insecure || exit 1

                    argocd app set ${ARGOCD_APP_NAME} --sync-policy none
                    argocd app sync ${ARGOCD_APP_NAME} --local .
                    argocd app set ${ARGOCD_APP_NAME} --sync-policy automated --self-heal

                    
                """
            }
        }
    }
}





    }
    post {
        success {
            script {
                echo "Docker image successfully built and pushed to Harbor registry"
                echo "Image tags:"
                echo "- ${env.HARBOR_PROJECT}/${env.DOCKER_IMAGE_NAME}:${env.BUILD_NUMBER}"
                echo "- ${env.HARBOR_PROJECT}/${env.DOCKER_IMAGE_NAME}:commit-${COMMIT_HASH}"
                echo "- ${env.HARBOR_PROJECT}/${env.DOCKER_IMAGE_NAME}:${BUILD_TIMESTAMP}"
                if (env.GITHUB_BRANCH == 'main') {
                    echo "- ${env.HARBOR_PROJECT}/${env.DOCKER_IMAGE_NAME}:${env.BUILD_NUMBER}"
                }
                
                // Example of sending a success notification
                emailext (
                    subject: "SUCCESS: Docker image built for ${env.GIT_REPO_NAME}",
                    body: """
                        Docker image successfully built and pushed to Harbor:
                        
                        Repository: ${env.HARBOR_PROJECT}/${env.DOCKER_IMAGE_NAME}
                        Tags:
                        - ${env.BUILD_NUMBER}
                        - commit-${COMMIT_HASH}
                        - ${BUILD_TIMESTAMP}
                        - ${BUILD_NUMBER}
                        
                        Build URL: ${env.BUILD_URL}
                    """,
                    to: 'dev-team@yourcompany.com'
                )
            }
        }
        failure {
            script {
                echo "Pipeline failed - check the logs for details"
                
                // Example of sending a failure notification
                emailext (
                    subject: "FAILED: Docker image build for ${env.GIT_REPO_NAME}",
                    body: """
                        Failed to build Docker image from repository ${env.GITHUB_REPO}.
                        
                        Build URL: ${env.BUILD_URL}
                        Build Number: ${env.BUILD_NUMBER}
                        Branch: ${env.GITHUB_BRANCH}jemptrip
                        
                        Please check the Jenkins logs for details.
                    """,
                    to: 'dev-team@yourcompany.com'
                )
            }
        }
        always {
            script {
                // Clean up workspace while preserving important artifacts
                archiveArtifacts artifacts: '**/docker-build*.log', allowEmptyArchive: true
                cleanWs(cleanWhenAborted: true, cleanWhenFailure: true, cleanWhenNotBuilt: true, cleanWhenUnstable: true)
            }
        }
        
    }
}
