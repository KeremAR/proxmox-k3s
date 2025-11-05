# CI/CD with Jenkins, SonarQube, and ArgoCD

This directory contains the scripts and configuration for setting up and running a comprehensive CI/CD pipeline using Jenkins.

## Overview

The CI/CD pipeline is designed to automate the building, testing, and deployment of the application services. It integrates security scanning at multiple levels ("shift-left" security) and uses a GitOps approach for deployments to Kubernetes, orchestrated by ArgoCD.

**Key Technologies:**
- **Jenkins**: The core CI/CD orchestrator.
- **SonarQube**: For static code analysis and quality gates.
- **Trivy**: For vulnerability and misconfiguration scanning (IaC, dependencies, and container images).
- **OWASP ZAP**: For dynamic application security testing (DAST).
- **Helm**: For packaging Kubernetes applications.
- **ArgoCD**: For declarative, GitOps-based deployments.
- **Jenkins Configuration as Code (JCasC)**: To manage Jenkins configuration declaratively.
- **Jenkins Shared Library**: To define reusable and complex pipeline steps in Groovy.

---

## Setup Scripts

### `7A-sonarqube.sh`

This script automates the installation of SonarQube into the Kubernetes cluster.

- **Purpose**: To provide a platform for continuous code quality and security analysis.
- **Method**: Deploys the official SonarQube Community Edition Helm chart into a dedicated `sonarqube` namespace.
- **Configuration**: It sets up SonarQube with a PostgreSQL database and persistent storage to ensure data is not lost.
- **Access**: It creates a Kubernetes Ingress resource, making the SonarQube UI accessible at `http://sonarqube.<YOUR_IP>.nip.io`.

### `7B-jenkins.sh`

This script installs a fully configured, production-ready Jenkins instance on Kubernetes.

- **Purpose**: To set up the central CI/CD engine.
- **Method**: Deploys the official Jenkins Helm chart using a highly customized set of values.
- **Configuration (via JCasC)**:
    - **Plugins**: Installs all necessary plugins for Kubernetes integration, GitHub, SonarQube, Docker, etc.
    - **Credentials**: Securely configures all required credentials (GitHub, SonarQube, ArgoCD) using Kubernetes secrets. **Note:** You must edit this script to add your personal tokens before running it.
    - **Kubernetes Cloud**: Configures Jenkins to dynamically spin up agent pods on demand for running pipeline jobs.
    - **Shared Library**: Connects Jenkins to a global shared library repository (`KeremAR/jenkins-shared-library2`) where custom pipeline logic is stored.
    - **Job Creation**: Automatically creates the `todo-app-ci` multibranch pipeline job, which scans the `proxmox-k3s` repository for branches and Pull Requests containing a `Jenkinsfile`.
- **Permissions**: Grants Jenkins `cluster-admin` rights, allowing it to deploy applications across different namespaces.
- **Access**: Creates an Ingress resource to make the Jenkins UI accessible at `http://jenkins.<YOUR_IP>.nip.io`.

---

## The CI/CD Pipeline (`Jenkinsfile`)

The `Jenkinsfile` defines the entire CI/CD process. It is designed to be flexible and robust, with different execution paths based on the context (Pull Request, main branch, or Git tag).

### Core Concepts

- **Shared Library**: The pipeline heavily relies on a `@Library` to abstract complex logic into reusable functions (e.g., `runUnitTests`, `argoDeployStaging`). This keeps the `Jenkinsfile` clean and readable.
- **Configuration Map**: All project-specific variables (service names, file paths, etc.) are defined in a `config` map at the top of the file, making it easy to manage.
- **Dynamic Agents**: The pipeline runs on agent pods that are created and destroyed automatically by the Kubernetes plugin, ensuring a clean and isolated environment for each run.
- **Immutable Image Tags**: Docker images are tagged with the 7-character Git commit SHA (`IMAGE_TAG`). This ensures that every commit produces a unique, traceable artifact.

### Pipeline Flow

The pipeline executes different stages based on the Git branch or tag that triggers it.

#### 1. Validation Flow (On Pull Requests and Feature Branches)
This flow is designed for fast feedback. Its goal is to validate code changes without deploying anything.
- **Linting**: Checks code style using `flake8`, `black`, and `hadolint`.
- **Static Analysis**: Scans for secrets, IaC misconfigurations, and dependency vulnerabilities with `Trivy`.
- **Unit Tests**: Runs unit tests for each service.
- **SonarQube Analysis**: Performs a deep static code analysis and sends the report to SonarQube (for PRs and `main`).
- **Build & Scan Images**: Builds all service images and scans them for vulnerabilities with `Trivy`.
- **Integration Tests**: Runs local end-to-end tests using `docker-compose`.

#### 2. Staging Flow (On Merge to `main` branch)
This flow automatically deploys the latest version of the application to a staging environment.
- **All Validation Stages**: Runs all the steps from the validation flow.
- **Push to Registry**: Pushes the built container images to the GitHub Container Registry (GHCR).
- **Deploy to Staging**: Updates the image tag in the GitOps repository. ArgoCD detects this change and automatically deploys the new version to the `staging` namespace.
- **Staging E2E & Security Tests**: Runs end-to-end tests and an OWASP ZAP dynamic security scan against the live staging environment to ensure everything works as expected.

#### 3. Production Flow (On `v*` Git Tag)
This is the final step to release a new version to production. It is triggered manually by creating and pushing a version tag.
- **Trigger**: `git tag v1.0.0 && git push origin v1.0.0`
- **Deploy to Production**: The pipeline updates the image tag for the production environment in the GitOps repository. ArgoCD detects this and rolls out the update to the `production` namespace.

---

## Shared Library Functions

The pipeline's logic is modularized into a [Jenkins Shared Library](https://www.jenkins.io/doc/book/pipeline/shared-libraries/). This keeps the `Jenkinsfile` declarative and easy to read, while the complex implementation details are handled by Groovy scripts.

### Utility Functions (`src/com/company/jenkins/Utils.groovy`)

This class contains static helper methods used across the pipeline.

#### `getPodTemplate()`

This function returns the YAML definition for the dynamic Jenkins agent pod that executes the pipeline stages.

- **Purpose**: To define a consistent, multi-container environment for all pipeline runs.
- **Key Features**:
    - **Multi-Container Setup**: The pod includes the standard `jnlp` agent, a `docker` (Docker-in-Docker) container for building images, an `argo` container with the ArgoCD CLI, and a `pythonlinting` container.
    - **Persistent Caching**: It mounts several Persistent Volume Claims (`jenkins-docker-cache-pvc`, `jenkins-trivy-cache-pvc`, `jenkins-tool-cache-pvc`). This is critical for performance, as it preserves the Docker layer cache, the Trivy vulnerability database, and other downloaded tools between pipeline runs, saving significant time.

#### `notifyGitHub()`

A simple logging helper to provide clear status messages in the Jenkins build log.

- **Purpose**: To standardize the success and failure messages at the end of a pipeline run.
- **Note**: This function prints to the Jenkins console; it does not directly interact with the GitHub API. GitHub commit status updates are handled by the Jenkins multibranch pipeline feature itself.

#### `getChangedServices(Map config)`

This is a powerful utility for optimizing pipeline execution on feature branches.

- **Purpose**: To determine which application services have been modified in a given branch compared to the `main` branch.
- **Execution**: It performs a `git fetch` to ensure it has the latest `main` branch data. It then runs `git diff --name-only` to get a list of all changed files. Finally, it iterates through this list and checks if any file path belongs to a known service directory (e.g., `user-service/`).
- **Output**: It returns a list of service objects that have changes, which is then consumed by other functions like `featureUnitTest` and `featureBuildServices`.


### Linting Functions (`vars/*.groovy`)

These scripts define global functions that can be called directly from the `Jenkinsfile` to perform linting.

#### `runPythonLinting(Map config)`

Checks Python code for style and formatting errors.

- **Purpose**: To enforce a consistent code style across all Python services.
- **Execution**: It runs `black --check` (for formatting) and `flake8` (for linting) inside a temporary `python:3.11-slim` container for a clean, reproducible environment.
- **Parameters**:
    - `pythonTargets` (List): Directories to scan (e.g., `['user-service/', 'todo-service/']`).
    - `flake8Args` (String): Optional arguments to pass to `flake8`.
    - `blackVersion` (String): Optional version of the `black` tool to use.
    - `flake8Version` (String): Optional version of the `flake8` tool to use.

#### `runHadolint(Map config)`

Lints all `Dockerfile`s in the project.

- **Purpose**: To ensure Dockerfiles are well-structured and follow best practices.
- **Execution**: It runs the official `hadolint/hadolint` container, mounting the workspace to scan the files.
- **Parameters**:
    - `dockerfiles` (List): A list of paths to the Dockerfiles to be checked.
    - `ignoreRules` (List): Optional list of rule IDs to ignore during the scan.

### Security Static Scans (`vars/*.groovy`)

This suite of functions integrates Trivy, an open-source security scanner, directly into the pipeline to perform "shift-left" security checks. These scans run on every commit to provide immediate feedback on potential security issues.

#### `ensureTrivyDB(Map config)`

This is a critical utility function that manages the Trivy vulnerability database.

- **Purpose**: To avoid re-downloading the large vulnerability database on every pipeline run, which significantly speeds up security scans.
- **Execution**: It checks for the existence of the database in a persistent cache (`/home/jenkins/.trivy-cache`). If the database is missing or a `forceUpdate` is requested, it runs a Docker container (`aquasec/trivy:latest`) to download and cache the latest version.

#### `runTrivySecretScan(Map config)`

Scans the entire codebase for hardcoded secrets like API keys, passwords, and private keys.

- **Purpose**: To prevent sensitive credentials from being accidentally committed to the repository.
- **Execution**: It runs Trivy in `fs` (filesystem) mode with the `--scanners secret` flag. To ensure safe parallel execution and high performance, it creates a temporary, isolated copy of the main Trivy database from the persistent cache (`/home/jenkins/.trivy-cache`) for the scan. This prevents file locking issues that occur when multiple Trivy instances access the same database simultaneously. The pipeline is configured to fail (`exit-code 1`) if any secrets with `HIGH` or `CRITICAL` severity are found.
- **Parameters**:
    - `failOnSecrets` (Boolean): Whether to fail the build if secrets are found. Defaults to `true`.
    - `severities` (String): Comma-separated list of severities to report (e.g., `'HIGH,CRITICAL'`).

#### `runTrivyIaCscan(Map config)`

Scans Infrastructure as Code (IaC) files for security misconfigurations.

- **Purpose**: To identify potential security risks in deployment configurations before they reach a live environment.
- **Execution**: It runs Trivy in `fs` (filesystem) mode with the `--scanners misconfig` flag against files like Kubernetes manifests, Helm charts, and Dockerfiles. To ensure safe parallel execution and high performance, it creates a temporary, isolated copy of the main Trivy database from the persistent cache (`/home/jenkins/.trivy-cache`) for the scan. This prevents file locking issues that occur when multiple Trivy instances access the same database simultaneously. The pipeline is configured to fail if any `MEDIUM`, `HIGH`, or `CRITICAL` issues are detected.
- **Parameters**:
    - `failOnIssues` (Boolean): Whether to fail the build on misconfigurations. Defaults to `true`.
    - `severities` (String): Severities to fail on (e.g., `'MEDIUM,HIGH,CRITICAL'`).

#### `runTrivyFSScan(Map config)`

Scans the filesystem for known vulnerabilities (CVEs) in application dependencies.

- **Purpose**: To detect vulnerable third-party libraries defined in dependency manifests.
- **Execution**: It runs Trivy in `fs` (filesystem) mode with the `--scanners vuln` flag against dependency files like `requirements.txt` and `package-lock.json`. To ensure safe parallel execution and high performance, it creates a temporary, isolated copy of the main Trivy database from the persistent cache (`/home/jenkins/.trivy-cache`) for the scan. This prevents file locking issues that occur when multiple Trivy instances access the same database simultaneously. The pipeline is configured to fail if any `HIGH` or `CRITICAL` vulnerabilities are found.
- **Parameters**:
    - `failOnVulnerabilities` (Boolean): Whether to fail the build on vulnerabilities. Defaults to `true`.
    - `severities` (String): Severities to fail on (e.g., `\'HIGH,CRITICAL\'`).

### Unit Testing and Code Quality Analysis (`vars/*.groovy`)

These functions handle running unit tests, generating code coverage reports, and performing deep static code analysis with SonarQube to enforce quality standards.

#### `runUnitTests(Map config)`

This is the main function for running unit tests for all backend services.

- **Purpose**: To validate the correctness of the application logic and generate code coverage metrics.
- **Execution**: It runs in parallel for all defined services. For each service, it builds a test-specific Docker image (using `Dockerfile.test`) and then runs `pytest` with coverage enabled (`--cov`).
- **Coverage Reports**: After the tests complete, it copies the generated `coverage.xml` report from the container to the Jenkins workspace (`coverage-reports/`). It then cleverly uses `sed` to fix the file paths in the XML report, making them relative to the service directory so SonarQube can correctly map coverage data to source files.

#### `featureUnitTest(Map config)`

An optimized version of the test runner designed for feature branches and pull requests.

- **Purpose**: To provide a much faster feedback loop for developers by only testing what has changed.
- **Execution**: It first calls `getChangedServices()` to get a list of services that have been modified compared to the `main` branch. It then runs the same Docker-based tests as `runUnitTests` but *only* for the changed services and, crucially, it skips coverage generation to save time.

#### `sonarQubeAnalysis(Map config)`

This function orchestrates the entire static analysis process with SonarQube.

- **Purpose**: To analyze code for bugs, vulnerabilities, code smells, and test coverage, and to enforce a quality gate on the code.
- **Execution Flow**:
    1.  **Configuration**: It dynamically generates a `sonar-project.properties` file, which defines the analysis scope, exclusions, and the location of the coverage reports generated by `runUnitTests`.
    2.  **Analysis**: It invokes the `sonar-scanner` tool within the `withSonarQubeEnv` context, which provides the necessary server URL and authentication token.
    3.  **Quality Gate**: It uses the `waitForQualityGate` step. This is a critical, blocking step that pauses the pipeline and waits for SonarQube to finish its analysis and return a status. If the project fails to meet the defined quality gate criteria (e.g., "Coverage is less than 80%"), this step fails the entire pipeline.
    4.  **Issue Reporting**: In a `finally` block, it always calls `fetchSonarQubeIssues` to ensure that analysis results are posted in the Jenkins log, even if the quality gate fails.

#### `fetchSonarQubeIssues(Map config)`

A utility function to provide immediate, actionable feedback directly within the Jenkins UI.

- **Purpose**: To show developers the specific issues reported by SonarQube without requiring them to navigate to the SonarQube dashboard.
- **Execution**: It uses `curl` to call the SonarQube REST API, requesting all open issues of `MAJOR` severity or higher. It then parses the JSON response and prints a clear, formatted summary of each issue (including file, line number, and message) to the Jenkins console.

### Building Service Images (`vars/*.groovy`)

These functions are responsible for creating the container images that will be deployed to Kubernetes.

#### `buildDockerImage(Map config)`

This is the core function that builds a single Docker image for a given service.

- **Purpose**: To create a tagged, versioned Docker image from a `Dockerfile`.
- **Execution**: It runs the `docker build` command. It then applies two tags to the resulting image:
    1.  A version-specific tag using the Git commit SHA (e.g., `.../todo-app-user-service:a1b2c3d`).
    2.  A `latest` tag.
- **Output**: It returns the full names of both the versioned and latest images.

#### `buildAllServices(Map config)`

Builds Docker images for all services defined in the pipeline configuration.

- **Purpose**: To ensure all microservices are built as part of the main pipeline run (e.g., on a merge to `main`).
- **Execution**: It iterates through the list of services and calls `buildDockerImage` for each one, running the builds in parallel to save time.

#### `featureBuildServices(Map config)`

An optimized build function for feature branches.

- **Purpose**: To speed up pipeline runs by only building images for services that have actually changed.
- **Execution**: It first calls `getChangedServices()` to identify the modified services. It then calls `buildDockerImage` in parallel, but only for the services in that returned list. If no services have changed, this step is skipped entirely.

### Image Security and SBOM Generation (`vars/*.groovy`)

This set of functions provides deep security insights into the final container images, scanning them for vulnerabilities and generating a full inventory of their components.

#### `runTrivyScan(Map config)`

Scans the newly built Docker images for known operating system and language-level vulnerabilities (CVEs).

- **Purpose**: To ensure that the container images being deployed do not contain known security flaws.
- **Execution**: It takes a list of image names and runs the `aquasec/trivy` scanner against each one in parallel. To solve database locking issues during these parallel scans, each job creates its own temporary, isolated copy of the vulnerability database from the persistent cache. It mounts the host\'s Docker socket (`/var/run/docker.sock`) to allow Trivy to inspect images directly from the Docker daemon. The pipeline is configured to fail if any `HIGH` or `CRITICAL` severity vulnerabilities are discovered.

#### `runTrivySBOM(Map config)`

Generates a Software Bill of Materials (SBOM) for each container image.

- **Purpose**: To create a comprehensive, machine-readable inventory of all components, libraries, and dependencies within each microservice's container image. This is crucial for supply chain security and vulnerability management.
- **Execution**: It uses Trivy to scan each image and generate an SBOM in the `CycloneDX` format. The scans are run in parallel, with each job using an isolated copy of the persistent Trivy database to prevent conflicts. The resulting JSON files are stored in the `sbom-reports/` directory and archived as build artifacts. If configured, it then triggers the `uploadSBOMsToDependencyTrack` function.

#### `uploadSBOMsToDependencyTrack(Map config)`

Uploads the generated SBOMs to a central OWASP Dependency-Track server.

- **Purpose**: To provide a centralized platform for continuous component analysis. Dependency-Track ingests the SBOMs and can track vulnerabilities across all microservices and versions over time, providing a holistic view of the project's security posture.
- **Execution**: It finds all `*.sbom.json` files in the `sbom-reports/` directory and uses the `dependencyTrackPublisher` step (from the Jenkins Dependency-Track plugin) to upload each one to a specific project in the Dependency-Track instance. This step is treated as informational and will not fail the pipeline if the upload fails.

### Integration Testing and Deployment (`vars/*.groovy`)

These functions handle the final stages of the validation and staging flows: running full end-to-end tests and publishing the validated images to a container registry.

#### `runIntegrationTests(Map config)`

This function provides the highest level of confidence before a deployment by running true end-to-end integration tests.

- **Purpose**: To validate that all microservices work together correctly in a realistic, containerized environment.
- **Execution Flow**:
    1.  **Environment Setup**: It uses `docker compose` with the `docker-compose.ci.yml` file to orchestrate the entire application stack. This special CI-focused file does not build images; instead, it uses the pre-built, version-tagged images created in the `buildAllServices` stage.
    2.  **Health Checks**: It waits for the `user-service` and `todo-service` to become fully operational by polling their health check endpoints.
    3.  **Test Execution**: Once the environment is ready, it executes the `scripts/e2e-test.sh` script. This script acts as a test runner, making a series of `curl` requests to the live services to simulate a real user workflow: registering a user, logging in, creating a todo, listing todos, and deleting a todo. This validates the full application logic, including inter-service communication and database interactions.
    4.  **Cleanup**: It uses a `finally` block to guarantee that `docker compose down -v` is always called, ensuring that the test environment (containers, networks, and volumes) is completely destroyed after the tests run, preventing resource leaks on the Jenkins agent.

#### `pushToRegistry(Map config)`

This function is the gateway to deployment. It publishes the final, validated container images to the GitHub Container Registry (GHCR).

- **Purpose**: To store the immutable build artifacts that will be used for staging and production deployments.
- **Execution**: This step runs on the `main` branch only after all previous validation stages (linting, static analysis, unit tests, and integration tests) have passed successfully. It uses the `withCredentials` helper to securely access the GitHub registry token, logs in, and then executes `docker push` for each of the version-tagged service images.

### Deployment and Post-Deployment Validation (`vars/*.groovy`)

This suite of functions manages the GitOps deployment process to staging and production environments, followed by crucial post-deployment tests to ensure stability and security.

#### `updateGitOpsManifest(Map config)`

This is a core utility function that automates the process of updating image tags and optionally target revisions within the GitOps repository. It is called by both `argoDeployStaging` and `argoDeployProductionMain`.

- **Purpose**: To declaratively update the desired state of the application in the GitOps repository, which ArgoCD then observes and applies.
- **Execution Flow**:
    1.  **Clone GitOps Repo**: The function first clones the specified GitOps repository (`gitops-epam`) into a temporary directory.
    2.  **Update Manifest**: It then uses `sed` commands to modify the relevant environment-specific manifest file (e.g., `argocd-manifests/environments/staging.yaml` or `production.yaml`). It updates the `frontend.image.tag`, `userService.image.tag`, and `todoService.image.tag` parameters with the new `imageTag` provided. If a `targetRevision` is also provided (typically for production releases), it updates that field as well.
    3.  **Commit and Push**: After modifying the file, it configures Git user details, commits the changes with a standardized message (e.g., "ci: Update staging image tags to build 123"), and pushes these changes back to the `main` branch of the GitOps repository.
    4.  **Cleanup**: Finally, it removes the temporary clone of the GitOps repository.
- **Key Role**: This function is critical for enabling the GitOps workflow, as it's the mechanism by which the CI pipeline communicates desired deployment changes to ArgoCD via the Git repository.

#### `argoDeployStaging(Map config)`

Deploys the application to the staging environment using a GitOps "App-of-Apps" pattern.

- **Purpose**: To automatically deploy every change merged to the `main` branch into a production-like staging environment.
- **Execution Flow**:
    1.  **Update Manifest**: It first calls `updateGitOpsManifest` to commit a change to the GitOps repository, updating the `staging.yaml` file with the new container image tag.
    2.  **Sync Root App**: It then uses the `argocd` CLI to sync the `root-app`. This is the core of the App-of-Apps pattern: the `root-app` detects the change in the manifest file and, in turn, updates the parameters of the child `staging-todo-app`.
    3.  **Wait for Health**: Finally, it executes `argocd app wait` on the child application. This command pauses the pipeline until ArgoCD reports that the application is fully synced and healthy, confirming that the new version has been successfully rolled out.

#### `runStagingE2ETests(Map config)`

Executes end-to-end tests against the live, newly deployed staging environment.

- **Purpose**: To verify that the deployed application is fully functional in a live Kubernetes environment.
- **Execution Flow**:
    1.  **Trust but Verify**: Before running any tests, it implements a "trust but verify" step. It uses `kubectl get rollout ...` to connect to the Kubernetes cluster and check the image tag of the currently running containers. It compares this with the pipeline's `IMAGE_TAG` to ensure the tests are running against the version that was just deployed.
    2.  **Run Tests**: It then executes the same `scripts/e2e-test.sh` script used in the earlier integration test phase, but this time it points to the public Ingress URLs of the staging services.

#### `runOwaspZapScan(Map config)`

Performs a Dynamic Application Security Test (DAST) against the staging environment.

- **Purpose**: To "shift-left" security by automatically scanning the live application for common web vulnerabilities on every deployment to staging.
- **Execution**: It runs the official OWASP ZAP Docker image, which executes a baseline passive scan and a spider to discover content.
- **Non-Blocking**: The scan is configured to be non-blocking (`-l WARN`), meaning it will report findings without failing the pipeline. This allows developers to see potential issues without halting the CI/CD process for lower-severity alerts.
- **Reporting**: It generates detailed HTML, JSON, and Markdown reports. A `finally` block ensures these reports are always archived, and the HTML report is published to the Jenkins UI for easy access.

#### `argoDeployProductionMain(Map config)`

Promotes a tested staging release to the production environment. This is the final, manual-gated step in the pipeline.

- **Purpose**: To provide a safe, controlled process for releasing a new version to production.
- **Trigger**: This function is only called on pipelines triggered by a Git tag (e.g., `v1.2.3`).
- **Execution Flow**:
    1.  **Identify Promotion Candidate**: The first step is to connect to the GitOps repository and read the image tag that is currently deployed to the `staging` environment. This version is considered stable and is the candidate for promotion.
    2.  **Update Production Manifest**: It then updates the `production.yaml` manifest in the GitOps repository, setting the image tag to the version it just identified from staging. It also sets the `targetRevision` to the pipeline's Git tag (`env.TAG_NAME`) for clear traceability.
    3.  **Sync and Wait**: Finally, just like the staging deployment, it syncs the `root-app` and waits for the `production-todo-app` to become healthy, confirming a successful production rollout.