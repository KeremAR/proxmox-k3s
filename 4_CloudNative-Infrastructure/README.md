# Cloud-Native Infrastructure: ArgoCD and Argo Rollouts

This document outlines the cloud-native infrastructure setup, focusing on the deployment strategy using ArgoCD for GitOps and Argo Rollouts for progressive delivery.

## ArgoCD and GitOps

ArgoCD is used as the GitOps controller. It continuously monitors application definitions stored in a dedicated Git repository and ensures that the live state in the Kubernetes cluster matches the state defined in Git.

### Installation

The `4B-install-argocd.sh` script handles the initial setup:
- Installs the ArgoCD controller in the `argocd` namespace.
- Creates an NGINX Ingress to expose the ArgoCD server dashboard.
- Installs the `argocd` CLI and performs the initial login.

### GitOps Structure: App of Apps

We use the "App of Apps" pattern to structure our GitOps repository. This provides a centralized and scalable way to manage multiple applications and environments.

- **`root-application.yaml`**: This is the parent application. It is configured to monitor a path in the GitOps repository (e.g., `environments/`) and automatically create any `Application` resources defined there. This allows for easy onboarding of new environments or applications.

- **Environment Applications (`staging.yaml`, `production.yaml`)**: These are child applications managed by the root application. Each file defines the deployment for a specific environment:
    - They point to the `todo-app` Helm chart.
    - They specify the target namespace (`staging` or `production`).
    - They provide environment-specific configurations using different Helm value files (`values-staging.yaml` or `values-prod.yaml`).
    - They are configured with an automated sync policy, ensuring that any changes merged to the main branch of the GitOps repository are automatically applied to the cluster.

**Note:** The GitOps manifests are maintained in a separate, dedicated Git repository.

## Argo Rollouts

We use Argo Rollouts to manage application deployments, enabling advanced deployment strategies like canary releases. This provides finer-grained control over the deployment process and reduces the risk of introducing a faulty version.

### Installation

The `4C-install-argo-rollouts.sh` script handles the installation of the Argo Rollouts controller and the necessary RBAC configuration for it to manage NGINX Ingress resources during traffic shifting.

### Rollout Resources

Instead of standard Kubernetes `Deployment` objects, we use Argo `Rollout` resources. These are defined for the `frontend`, `todo-service`, and `user-service`.

- `helm-charts/todo-app/templates/frontend-deployment.yaml`
- `helm-charts/todo-app/templates/todo-service-deployment.yaml`
- `helm-charts/todo-app/templates/user-service-deployment.yaml`

### Canary Deployment Strategy

The rollouts are configured to perform a canary release. The traffic is gradually shifted to the new version, with analysis steps in between to ensure the new version is healthy.

The strategy is defined in the `strategy.canary` section of the `Rollout` resources and includes the following steps:
1.  **Set Weight 20%**: Shift 20% of the traffic to the canary version.
2.  **Analysis**: Run automated health checks against the canary.
3.  **Pause**: Pause the rollout indefinitely until it is manually promoted. This allows for manual verification.
4.  **Set Weight 40%**: Shift 40% of traffic.
5.  **Pause (10s)**: A short pause.
6.  **Analysis**: Run health checks again.
7.  **Set Weight 60%**: Shift 60% of traffic.
8.  **Pause (10s)**: A short pause.
9.  **Analysis**: Run final health checks.
10. **Full Rollout**: If all analyses pass, the rollout proceeds to 100%.

Traffic is managed by the NGINX Ingress controller, as specified in the `trafficRouting` section of the rollouts.

### Canary and Stable Services

For each service, there are two `Service` objects to manage traffic during a rollout:
- **Stable Service**: (`<service-name>`) Points to the stable, production pods.
- **Canary Service**: (`<service-name>-canary`) Points to the canary (new version) pods.

These services are defined in:
- `helm-charts/todo-app/templates/frontend-canary-service.yaml`
- `helm-charts/todo-app/templates/todo-service-canary-service.yaml`
- `helm-charts/todo-app/templates/user-service-canary-service.yaml`

### Analysis Templates

Automated analysis is crucial for safe canary deployments. We use `AnalysisTemplate` resources to define the health checks.

- **`analysistemplate-backend.yaml`**: This template is used for the backend services (`todo-service`, `user-service`). It sends a request to the `/health` endpoint and checks if the `status` field in the JSON response is `"healthy"`.

- **`analysistemplate-frontend.yaml`**: This template is for the `frontend`. It checks for an `HTTP 200` status code on the root (`/`) URL.

These templates are referenced in the `analysis` steps of the `Rollout` resources.

## Management and Monitoring

### Useful Commands

- **Open the Rollouts Dashboard**:
  ```shell
  kubectl argo rollouts dashboard
  ```

- **Watch a Rollout**:
  ```shell
  kubectl argo rollouts get rollout <rollout-name> -n <namespace> --watch
  ```

- **Promote a Paused Rollout**:
  ```shell
  kubectl argo rollouts promote <rollout-name> -n <namespace>
  ```

- **Abort a Rollout**:
  ```shell
  kubectl argo rollouts abort <rollout-name> -n <namespace>
  ```