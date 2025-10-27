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
    repoUrl: 'github.com/KeremAR/gitops-epam', // GitOps repository (not used for main branch deploy)

    dockerfilesToHadolint: [
        'user-service/Dockerfile',
        'user-service/Dockerfile.test',
        'todo-service/Dockerfile',
        'todo-service/Dockerfile.test',
        'frontend2/frontend/Dockerfile'
    ],
    hadolintIgnoreRules: ['DL3008', 'DL3009', 'DL3016', 'DL3059'],

//--------------------Trivy Scan Disabled for Now--------------------
    /*
    trivySeverities: 'HIGH,CRITICAL',
    trivyFailBuild: true,
    trivySkipDirs: ['/app/node_modules'],
    */

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

        stage('Static Code Analysis') {
            when {
                not { tag 'v*' }
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
                    echo "🔨 Building all services..."
                    def builtImages = buildAllServices(
                        services: config.services,
                        registry: config.registry,
                        username: config.username,
                        imageTag: env.IMAGE_TAG,
                        appName: config.appName
                    )
                    env.BUILT_IMAGES = builtImages.join(',')
                    echo "Built images: ${env.BUILT_IMAGES}"
                }
            }
        }

        stage('Security Scan') {
            steps {
                script {
                    echo "🛡️ Scanning built images for vulnerabilities..."
                     echo "----------------------SKIPPING FOR NOW----------------------"
/*
//-------------------- Trivy Scan Disabled for Now--------------------

                    def allImages = env.BUILT_IMAGES.split(',')
                    // Filter out 'latest' tags to avoid scanning the same image twice
                    // Use a unique variable name 'image' instead of the implicit 'it' to avoid compilation errors
                    def imagesToScan = allImages.findAll { image -> !image.endsWith(':latest') }
                    echo "Filtered images to scan: ${imagesToScan}"

                    runTrivyScan(
                        images: imagesToScan,
                        severities: config.trivySeverities,
                        failOnVulnerabilities: config.trivyFailBuild,
                        skipDirs: config.trivySkipDirs
                    )
                    */
                }
            }
        }

        stage('Unit Tests') {
            when {
                not { tag 'v*' }
            }
            steps {
                script {
                    echo "🧪 Running unit tests..."
                    runUnitTests(services: config.unitTestServices)
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

        stage('Deploy to Production') {
            when {
                branch 'main'
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
                com.company.jenkins.Utils.notifyGitHub(this, 'success', 'Pipeline completed successfully!', config.deploymentUrl)
            }
        }
        failure {
            script {
                com.company.jenkins.Utils.notifyGitHub(this, 'failure', 'Pipeline failed!')
            }
        }
    }
}
