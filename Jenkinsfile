@Library('todo-app-shared-library') _


// All project-specific configuration is defined here
def config = [
    appName: 'todo-app',
    services: [
        [name: 'user-service', dockerfile: 'user-service/Dockerfile'],
        [name: 'todo-service', dockerfile: 'todo-service/Dockerfile'],
        [name: 'frontend', dockerfile: 'frontend2/frontend/Dockerfile', context: 'frontend2/frontend/']
    ],
    // Services that have unit tests to be run individually
    unitTestServices: [
        [name: 'user-service', dockerfile: 'user-service/Dockerfile.test', context: '.'],
        [name: 'todo-service', dockerfile: 'todo-service/Dockerfile.test', context: '.']
    ],

    composeFile: 'docker-compose.test.yml',
    // Services to be deployed to Kubernetes
    deploymentServices: ['user-service', 'todo-service', 'frontend'],

    // Helm deployment configuration
    helmReleaseName: 'todo-app',
    helmChartPath: 'helm-charts/todo-app', // Path to your chart directory
    helmValuesFile: 'helm-charts/todo-app/values.yaml', // Base values file
    helmValuesStagingFile: 'helm-charts/todo-app/values-staging.yaml', // Staging values file
    helmValuesProdFile: 'helm-charts/todo-app/values-prod.yaml', // Production values file (for image tags)
    helmDockerConfigJsonCredentialsId: 'github-registry-dockerconfig', // Jenkins credential ID for the docker config json

    // ArgoCD Configuration
    argoCdUserCredentialId: 'argocd-username',
    argoCdPassCredentialId: 'argocd-password',
    argoCdStagingAppName: 'staging-todo-app',
    argoCdProdAppName: 'production-todo-app',
    gitPushCredentialId: 'github-webhook', // Git'e push yapmak için credential
    gitOpsRepo: 'github.com/KeremAR/gitops-epam', // GitOps repository for manifest updates

    dockerfilesToHadolint: [
        'user-service/Dockerfile',
        'user-service/Dockerfile.test',
        'todo-service/Dockerfile',
        'todo-service/Dockerfile.test',
        'frontend2/frontend/Dockerfile'
    ],
    hadolintIgnoreRules: ['DL3008', 'DL3009', 'DL3016', 'DL3059'],

    trivySeverities: 'HIGH,CRITICAL',
    trivyFailBuild: true,
    trivySkipDirs: ['/app/node_modules'],

    registry: 'ghcr.io',
    username: 'keremar',
    namespace: 'todo-app', // Bu artık staging/prod için override edilecek
    manifestsPath: 'k8s',
    deploymentUrl: 'epam-proxmox-k3s',


    sonarScannerName: 'SonarQube-Scanner', // Name from Jenkins -> Tools
    sonarServerName: 'sq1',               // Name from Jenkins -> System
    sonarProjectKeyPlugin: 'proxmox-k3s-epam',

]

pipeline {
    agent {
        kubernetes {
            defaultContainer 'jnlp'
            yaml com.company.jenkins.Utils.getPodTemplate()
        }
    }

    environment {
        // BUILD_NUMBER, her build için Jenkins tarafından otomatik olarak artırılan bir ortam değişkenidir.
        // Docker imajlarını benzersiz bir şekilde etiketlemek için kullanılır.
        IMAGE_TAG = "${BUILD_NUMBER}"
        REGISTRY_CREDENTIALS = 'github-registry'

    }

    stages {
        // --- AŞAMA 1: DOĞRULAMA (VALIDATION) ---
        // Bu aşamalar, production'a dağıtım yapılan tag'ler DIŞINDAKİ tüm branch'lerde (feature/*, master, vb.) çalışır.
        // Amaç, kodu build etmek, analiz etmek ve test etmektir.
        stage('Checkout') {
            steps {
                checkout scm
            }
        }

                // 🆕 Static Security Scan - Runs BEFORE building images (Shift-Left Security)
        stage('Static Security Scan') {
            when {
                allOf {
                    not { tag 'v*' }
                    anyOf {
                        expression { env.CHANGE_ID != null }
                        branch 'main'
                    }
                }
            }
            steps {
                script {
                    echo "🔒 Running static security scans (no image build required)..."
                    parallel([
                        "IaC Security Scan": {
                            echo "🔒 Scanning Infrastructure as Code for misconfigurations..."
                            runTrivyIaCscan(
                                targets: ['k8s/', 'helm-charts/', '.'],
                                severities: config.trivySeverities,
                                failOnIssues: config.trivyFailBuild,
                                skipDirs: config.trivySkipDirs
                            )
                        },
                        "Dependency Vulnerability Scan": {
                            echo "📦 Scanning dependencies for known vulnerabilities..."
                            runTrivyFSScan(
                                target: '.',
                                severities: config.trivySeverities,
                                failOnVulnerabilities: config.trivyFailBuild,
                                skipDirs: config.trivySkipDirs
                            )
                        }
                    ])
                    echo "✅ Static security scans passed!"
                }
            }
        }

        stage('Unit Tests') {
            when {
                not { tag 'v*' }
            }
            steps {
                script {
                    // Feature branches (not PR): Only test changed services (fast feedback)
                    // PR + Main branch: Full test suite with coverage for SonarQube
                    if (env.CHANGE_ID) {
                        echo "🔍 Pull Request detected (#${env.CHANGE_ID}) - running full test suite with coverage..."
                        runUnitTests(services: config.unitTestServices)
                    } else if (env.BRANCH_NAME =~ /^feature\/.*/) {
                        echo "🧪 Feature branch - running tests for changed services only (fast feedback)..."
                        featureUnitTest(services: config.unitTestServices)
                    } else {
                        echo "🧪 Running full unit test suite with coverage..."
                        runUnitTests(services: config.unitTestServices)
                    }
                }
            }
        }

        stage('Static Code Analysis') {
            when {
                allOf {
                    not { tag 'v*' }
                    anyOf {
                        // Run on PR (for merge quality check)
                        expression { env.CHANGE_ID != null }
                        // Run on main branch
                        branch 'main'
                    }
                }
            }
            steps {
                script {
                    echo "🧹 Running Hadolint on all Dockerfiles..."
                    runHadolint(
                        dockerfiles: config.dockerfilesToHadolint,
                        ignoreRules: config.hadolintIgnoreRules
                    )

                    sonarQubeAnalysis(
                        scannerName: config.sonarScannerName,
                        serverName: config.sonarServerName,
                        projectKey: config.sonarProjectKeyPlugin
                    )

                }
            }
        }



        stage('Build Services') {
            when {
                not { tag 'v*' }
            }
            steps {
                script {
                    def builtImages = []

                    // Feature branches (not PR): Only build changed services (fast feedback)
                    // PR + Main branch: Build all services for quality check
                    if (env.CHANGE_ID) {
                        echo "🔍 Pull Request detected - building all services for quality check..."
                        builtImages = buildAllServices(
                            services: config.services,
                            registry: config.registry,
                            username: config.username,
                            imageTag: env.IMAGE_TAG,
                            appName: config.appName
                        )
                    } else if (env.BRANCH_NAME =~ /^feature\/.*/) {
                        echo "🔨 Feature branch - building changed services only (fast feedback)..."
                        builtImages = featureBuildServices(
                            services: config.services,
                            registry: config.registry,
                            username: config.username,
                            imageTag: env.IMAGE_TAG,
                            appName: config.appName
                        )
                    } else {
                        echo "🔨 Building all services..."
                        builtImages = buildAllServices(
                            services: config.services,
                            registry: config.registry,
                            username: config.username,
                            imageTag: env.IMAGE_TAG,
                            appName: config.appName
                        )
                    }

                    // Handle case where no services were built (e.g., infrastructure-only changes)
                    if (builtImages && builtImages.size() > 0) {
                        env.BUILT_IMAGES = builtImages.join(',')
                        echo "Built images: ${env.BUILT_IMAGES}"
                    } else {
                        env.BUILT_IMAGES = ""
                        echo "⚠️ No images were built (infrastructure-only changes)"
                    }
                }
            }
        }

        // Image Security Scan - Scans built Docker images (runs AFTER build)
        stage('Image Security Scan') {
            when {
                allOf {
                    not { tag 'v*' }
                    anyOf {
                        // Run on PR (for merge security check)
                        expression { env.CHANGE_ID != null }
                        // Run on main branch
                        branch 'main'
                    }
                }
            }
            steps {
                script {
                    echo "🛡️ Scanning built images for vulnerabilities..."
                    runTrivyScan(
                        images: env.BUILT_IMAGES.split(','),
                        severities: config.trivySeverities,
                        failOnVulnerabilities: config.trivyFailBuild,
                        skipDirs: config.trivySkipDirs
                    )
                }
            }
        }

        stage('Integration Tests') {
            when {
                anyOf {
                    // Run on PR (smoke tests for merge quality check)
                    expression { env.CHANGE_ID != null }
                    // Run on main branch
                    branch 'main'
                }
            }
            steps {
                script {
                    echo "🧪 Running backend integration tests (smoke tests)..."
                    echo "----------------------SKIPPING FOR NOW----------------------"
                    // runIntegrationTests(services: config.integrationTestServices)
                }
            }
        }

        stage('Push to Registry') {
            when {
                branch 'main'
            }
            steps {
                script {
                    echo "🚀 Pushing images to registry..."
                    def images = env.BUILT_IMAGES.split(',')
                    echo "Images to push: ${images}"
                    pushToRegistry([
                        images: images,
                        credentialsId: env.REGISTRY_CREDENTIALS
                    ])
                }
            }
        }

        stage('Deploy to Staging') {
            when {
                branch 'main'
            }
            steps {
                script {

                    argoDeployStaging(config)
                }
            }
        }


        // 1. Create a tag (semantic versioning recommended):
        //    git tag v1.0.0
        // 2. Push the tag to trigger production deployment:
        //    git push origin v1.0.0
        stage('Deploy to Production') {
            when {
                tag 'v*'
            }
            steps {
                script {

                   argoDeployProductionMain(config)
                }
            }
        }
    }


    post {
        always {
            echo 'Cleaning up the workspace...'
            deleteDir()
        }
        success {
            script {
                // Determine if deployment happened
                def deploymentMsg = 'Pipeline completed successfully!'
                def deploymentUrl = ''

                if (env.TAG_NAME) {
                    // Tag build - deployed to production
                    deploymentMsg = 'Production deployment completed successfully!'
                    deploymentUrl = 'production.epam-proxmox-k3s'
                } else if (env.BRANCH_NAME == 'main') {
                    // Main branch - deployed to staging
                    deploymentMsg = 'Staging deployment completed successfully!'
                    deploymentUrl = 'staging.epam-proxmox-k3s'
                } else if (env.CHANGE_ID) {
                    // PR - no deployment, just validation
                    deploymentMsg = "Pull Request #${env.CHANGE_ID} validation completed successfully!"
                } else {
                    // Feature branch - no deployment
                    deploymentMsg = 'Feature branch validation completed successfully!'
                }

                com.company.jenkins.Utils.notifyGitHub(this, 'success', deploymentMsg, deploymentUrl)
            }
        }
        failure {
            script {
                def failureMsg = 'Pipeline failed!'

                if (env.TAG_NAME) {
                    failureMsg = "Production deployment failed for tag ${env.TAG_NAME}!"
                } else if (env.BRANCH_NAME == 'main') {
                    failureMsg = 'Staging deployment failed!'
                } else if (env.CHANGE_ID) {
                    failureMsg = "Pull Request #${env.CHANGE_ID} validation failed!"
                } else {
                    failureMsg = 'Feature branch validation failed!'
                }

                com.company.jenkins.Utils.notifyGitHub(this, 'failure', failureMsg)
            }
        }
    }
}
