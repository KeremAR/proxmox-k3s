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
    
    // Integration test configuration (uses CI-optimized compose file with pre-built images)
    integrationTestComposeFile: 'docker-compose.ci.yml',
    integrationTestUserServiceUrl: 'http://localhost:8001',
    integrationTestTodoServiceUrl: 'http://localhost:8002',
    integrationTestHealthCheckTimeout: 120,
    
    // Staging E2E test configuration (runs against LIVE staging deployment)
    stagingE2ETestScriptPath: 'scripts/e2e-test.sh',
    stagingUserServiceUrl: 'http://user-service.staging.svc.cluster.local:8001',
    stagingTodoServiceUrl: 'http://todo-service.staging.svc.cluster.local:8002',
    stagingNamespace: 'staging',
    stagingUserServiceDeployment: 'user-service',
    stagingTodoServiceDeployment: 'todo-service',

    // Services to be deployed to Kubernetes
    deploymentServices: ['user-service', 'todo-service', 'frontend'],

    // Helm deployment configuration
    helmReleaseName: 'todo-app',
    helmChartPath: 'helm-charts/todo-app', // Path to your chart directory
    helmValuesFile: 'helm-charts/todo-app/values.yaml', // Base values file
    helmValuesStagingFile: 'helm-charts/todo-app/values-staging.yaml', // Staging values file
    helmValuesProdFile: 'helm-charts/todo-app/values-prod.yaml', // Production values file (for image tags)
    helmDockerConfigJsonCredentialsId: 'github-registry-dockerconfig', // Jenkins credential ID for the docker config json

    // ArgoCD Configuration (App-of-Apps Pattern)
    argoCdUserCredentialId: 'argocd-username',
    argoCdPassCredentialId: 'argocd-password',
    argoCdRootAppName: 'root-app',  // Root app that watches argocd-manifests/
    argoCdStagingAppName: 'staging-todo-app',  // Child app for staging
    argoCdProdAppName: 'production-todo-app',  // Child app for production
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

    // OWASP ZAP Security Scan Configuration
    zapTargetUrl: 'http://todo-app-staging.192.168.0.111.nip.io/',  // Target URL for ZAP scan (change this to your staging URL)
    zapScanLevel: 'WARN',  // Alert level: WARN = don't fail build on findings
    zapScanTimeout: 30,  // Scan timeout in minutes

    // Dependency-Track SBOM Management Configuration
    dependencyTrackEnabled: false,  // Set to true to enable SBOM upload to Dependency-Track
    dependencyTrackProjectName: 'todo-app',  // Project name in Dependency-Track
    dependencyTrackAutoCreate: true,  // Auto-create project if it doesn't exist

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
        // Use Git commit SHA as image tag for immutability and traceability
        // This ensures that same code always gets same image tag, regardless of Jenkins build number
        // Benefits:
        //   - Restart from stage doesn't break deployment chain
        //   - K8s image tag directly shows which code is running
        //   - Professional standard in production environments
        IMAGE_TAG = sh(script: 'git rev-parse --short=7 HEAD', returnStdout: true).trim()
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


        stage('Linting') {
            when {
                not { tag 'v*' }
            }
            steps {



                script {
                 echo "commented temporary for fast feedback"

                //     parallel([
                //         "Python Black & Flake8": {
                //             echo "🧹 Running Python Black & Flake8 linting..."
                //             runPythonLinting([
                //                 pythonTargets: ['user-service/', 'todo-service/'],
                //                 flake8Args: '--max-line-length=88 --extend-ignore=E203',
                //                 blackVersion: '25.9.0',
                //                 flake8Version: '7.3.0'
                //             ])
                //         },
                //         "Hadolint": {
                //             echo "🧹 Running Hadolint on all Dockerfiles..."
                //             runHadolint(
                //                 dockerfiles: config.dockerfilesToHadolint,
                //                 ignoreRules: config.hadolintIgnoreRules
                //             )
                //         }
                //     ])
                }
            }
        }

                // 🆕 Static Security Scan - Runs BEFORE building images (Shift-Left Security)
        stage('Security - Static Analysis') {
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
                             echo "commented temporary for fast feedback"

                //     echo "🔒 Running static security scans (no image build required)..."
                    
                //     // Ensure Trivy DB is available once (uses persistent cache)
                //     ensureTrivyDB()
                    
                //     // Run all security scans in parallel for faster feedback
                //     parallel([
                //         "Secret Scan": {
                //             echo "🔐 Scanning repository for exposed secrets..."
                //             runTrivySecretScan(
                //                 target: '.',
                //                 severities: config.trivySeverities,
                //                 failOnSecrets: config.trivyFailBuild,
                //                 skipDirs: config.trivySkipDirs
                //             )
                //         },
                //         "IaC Security Scan": {
                //             echo "🔒 Scanning Infrastructure as Code for misconfigurations..."
                //             runTrivyIaCscan(
                //                 targets: ['k8s/', 'helm-charts/', '.'],
                //                 severities: config.trivySeverities,
                //                 failOnIssues: config.trivyFailBuild,
                //                 skipDirs: config.trivySkipDirs
                //             )
                //         },
                //         "Dependency Vulnerability Scan": {
                //             echo "📦 Scanning dependencies for known vulnerabilities..."
                //             runTrivyFSScan(
                //                 target: '.',
                //                 severities: config.trivySeverities,
                //                 failOnVulnerabilities: config.trivyFailBuild,
                //                 skipDirs: config.trivySkipDirs
                //             )
                //         }
                //     ])
                    
                //     echo "✅ All static security scans passed!"
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

                   
                        echo "🧪 Running full unit test suite with coverage..."
                        runUnitTests(services: config.unitTestServices)
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

                     echo "commented temporary for fast feedback"

                    // sonarQubeAnalysis(
                    //     scannerName: config.sonarScannerName,
                    //     serverName: config.sonarServerName,
                    //     projectKey: config.sonarProjectKeyPlugin
                    // )

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
                    echo "✅ Built images: ${env.BUILT_IMAGES}"
                }
            }
        }

        // Image Security Scan - Scans built Docker images (runs AFTER build)
        stage('Image Security Scan') {
            when {
                allOf {
                    not { tag 'v*' }
                    anyOf {
                        expression { env.CHANGE_ID != null }
                        branch 'main'
                    }
                    // Only run if images were built
                    expression { env.BUILT_IMAGES && env.BUILT_IMAGES != "" }
                }
            }
            steps {
                script {
                                         echo "commented temporary for fast feedback"


                    // echo "🛡️ Scanning built Docker images for vulnerabilities and generating SBOM..."
                    // echo "📋 Images to scan: ${env.BUILT_IMAGES}"
                    
                    // // Ensure DB is available (will skip if already exists from previous stage)
                    // ensureTrivyDB()
                    
                    // // Step 1: Vulnerability Scan (must pass before SBOM generation)
                    // runTrivyScan(
                    //     images: env.BUILT_IMAGES.split(','),
                    //     severities: config.trivySeverities,
                    //     failOnVulnerabilities: config.trivyFailBuild,
                    //     skipDirs: config.trivySkipDirs
                    // )
                    
                    // echo "✅ All images passed security scan!"
                    
                    // // Step 2: Generate SBOM (Software Bill of Materials)
                    // runTrivySBOM(
                    //     images: env.BUILT_IMAGES.split(','),
                    //     format: 'cyclonedx',
                    //     outputDir: 'sbom-reports',
                    //     skipDirs: config.trivySkipDirs,
                    //     uploadToDependencyTrack: config.dependencyTrackEnabled,
                    //     dependencyTrackProjectName: config.dependencyTrackProjectName,
                    //     dependencyTrackProjectVersion: env.IMAGE_TAG,
                    //     dependencyTrackAutoCreate: config.dependencyTrackAutoCreate
                    // )
                    
                    // echo "✅ Image security scan and SBOM generation completed!"
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


                    echo "commented temporary for fast feedback"

                    // runIntegrationTests(
                    //     composeFile: config.integrationTestComposeFile,
                    //     userServiceUrl: config.integrationTestUserServiceUrl,
                    //     todoServiceUrl: config.integrationTestTodoServiceUrl,
                    //     healthCheckTimeout: config.integrationTestHealthCheckTimeout,
                    //     builtImages: env.BUILT_IMAGES,
                    //     imageTag: env.IMAGE_TAG,
                    //     testScriptPath: 'scripts/e2e-test.sh'  // Project-specific test script
                    // )
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
                    echo "🔍 Deploying all services to staging..."
                    
                    // Extract service names from configs
                    def servicesToDeploy = config.services
                    echo "📋 Services to deploy: ${servicesToDeploy.collect { it.name }.join(', ')}"
                    
                    argoDeployStaging([
                        services: servicesToDeploy,
                        argoCdUserCredentialId: config.argoCdUserCredentialId,
                        argoCdPassCredentialId: config.argoCdPassCredentialId,
                        argoCdRootAppName: config.argoCdRootAppName,
                        gitOpsRepo: config.gitOpsRepo,
                        gitPushCredentialId: config.gitPushCredentialId
                    ])
                }
            }
        }



        stage('Staging E2E Tests') {
            when {
                branch 'main'
            }
            steps {
                script {
                                        echo "commented temporary for fast feedback"

        //             runStagingE2ETests(
        //                 testScriptPath: config.stagingE2ETestScriptPath,
        //                 stagingUserServiceUrl: config.stagingUserServiceUrl,
        //                 stagingTodoServiceUrl: config.stagingTodoServiceUrl,
        //                 namespace: config.stagingNamespace,
        //                 userServiceDeploymentName: config.stagingUserServiceDeployment,
        //                 todoServiceDeploymentName: config.stagingTodoServiceDeployment
        //             )
                }
            }
        }

        // stage('OWASP ZAP Scan') {
        //     when {
        //         branch 'main'
        //     }
        //     steps {
        //         script {
        //             runOwaspZapScan(
        //                 targetUrl: config.zapTargetUrl,
        //                 scanLevel: config.zapScanLevel,
        //                 timeout: config.zapScanTimeout
        //             )
        //         }
            // }
        // }

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
                    // Pass services list to production deployment
                    def productionConfig = config.clone()
                    productionConfig.services = config.services.collect { it.name }
                    argoDeployProductionMain(productionConfig)
                }
            }
        }
    }


    post {
        always {
            script {
                echo 'Cleaning up the workspace...'
                try {
                    deleteDir()
                    echo '✅ Workspace cleaned successfully'
                } catch (e) {
                    echo '⚠️ Warning: Could not fully clean workspace (permission issues with Docker-created files)'
                    echo "This is non-critical and won't affect the pipeline result."
                    // Don't fail the pipeline due to cleanup issues
                }
            }
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
