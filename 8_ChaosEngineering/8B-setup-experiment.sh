#!/bin/bash

# ==============================================================================
# 8B - Setup Litmus Chaos Experiment
# ==============================================================================
# Purpose: Create Project, Environment, Agent, and Test Workflow
# Prerequisites: Run 8-deploy-litmus.sh first
# ==============================================================================

set -e

# Step 10: Create Test Chaos Workflow
echo "Step 10: Creating Test Chaos Workflow (pod-delete)..."

# Create a workflow based on the working deneme2.yml format
cat > /tmp/pod-delete-workflow.yaml <<EOF
apiVersion: argoproj.io/v1alpha1
kind: Workflow
metadata:
  name: pod-delete-test
  namespace: litmus
  labels:
    subject: "pod-delete-test"
spec:
  entrypoint: custom-chaos
  serviceAccountName: argo-chaos
  securityContext:
    runAsNonRoot: false
    runAsUser: 0
  arguments:
    parameters:
      - name: adminModeNamespace
        value: litmus
  templates:
    - name: custom-chaos
      steps:
        - - name: install-chaos-experiments
            template: install-chaos-experiments
        - - name: run-chaos
            template: run-chaos
        - - name: cleanup-chaos-resources
            template: cleanup-chaos-resources
    - name: install-chaos-experiments
      inputs:
        artifacts:
          - name: pod-delete
            path: /tmp/pod-delete.yaml
            raw:
              data: |
                apiVersion: litmuschaos.io/v1alpha1
                description:
                  message: |
                    Deletes a pod belonging to a deployment
                kind: ChaosExperiment
                metadata:
                  name: pod-delete
                  labels:
                    name: pod-delete
                    app.kubernetes.io/part-of: litmus
                    app.kubernetes.io/component: chaosexperiment
                    app.kubernetes.io/version: 3.22.0
                spec:
                  definition:
                    scope: Namespaced
                    permissions:
                      - apiGroups:
                          - ""
                          - "apps"
                          - "batch"
                          - "litmuschaos.io"
                          - "argoproj.io"
                        resources:
                          - "pods"
                          - "deployments"
                          - "jobs"
                          - "chaosengines"
                          - "chaosexperiments"
                          - "chaosresults"
                          - "rollouts"
                        verbs:
                          - "create"
                          - "list"
                          - "get"
                          - "patch"
                          - "update"
                          - "delete"
                          - "deletecollection"
                    image: litmuschaos.docker.scarf.sh/litmuschaos/go-runner:3.22.0
                    imagePullPolicy: Always
                    args:
                      - -c
                      - ./experiments -name pod-delete
                    command:
                      - /bin/bash
                    env:
                      - name: TOTAL_CHAOS_DURATION
                        value: "30"
                      - name: RAMP_TIME
                        value: ""
                      - name: FORCE
                        value: "true"
                      - name: CHAOS_INTERVAL
                        value: "5"
                      - name: PODS_AFFECTED_PERC
                        value: ""
                      - name: TARGET_CONTAINER
                        value: ""
                      - name: TARGET_PODS
                        value: ""
                      - name: DEFAULT_HEALTH_CHECK
                        value: "false"
                      - name: NODE_LABEL
                        value: ""
                      - name: SEQUENCE
                        value: parallel
                    labels:
                      name: pod-delete
                      app.kubernetes.io/part-of: litmus
                      app.kubernetes.io/component: experiment-job
                      app.kubernetes.io/version: 3.22.0
      container:
        image: litmuschaos/k8s:2.11.0
        command:
          - sh
          - -c
        args:
          - kubectl apply -f /tmp/pod-delete.yaml -n {{workflow.parameters.adminModeNamespace}} && sleep 30
    - name: run-chaos
      inputs:
        artifacts:
          - name: pod-delete
            path: /tmp/chaosengine.yaml
            raw:
              data: |
                apiVersion: litmuschaos.io/v1alpha1
                kind: ChaosEngine
                metadata:
                  namespace: "{{workflow.parameters.adminModeNamespace}}"
                  generateName: pod-delete-
                  labels:
                    workflow_run_id: "{{workflow.uid}}"
                spec:
                  appinfo:
                    appns: 'staging'
                    applabel: 'app=todo-service'
                    appkind: 'rollout'
                  engineState: 'active'
                  chaosServiceAccount: litmus-admin
                  experiments:
                    - name: pod-delete
                      spec:
                        components:
                          env:
                            - name: TOTAL_CHAOS_DURATION
                              value: '30'
                            - name: CHAOS_INTERVAL
                              value: '10'
                            - name: FORCE
                              value: 'false'
                        probe:
                          - name: "check-todo-service"
                            type: "httpProbe"
                            httpProbe/inputs:
                              url: "http://todo-service.staging.svc.cluster.local:8002/ready"
                              insecureSkipVerify: false
                              responseTimeout: 10000
                              method:
                                get:
                                  criteria: "=="
                                  responseCode: "200"
                            mode: "Edge"
                            runProperties:
                              probeTimeout: 10s
                              interval: 5s
                              retry: 2
      container:
        image: litmuschaos/litmus-checker:latest
        args:
          - -file=/tmp/chaosengine.yaml
          - -saveName=/tmp/engine-name
    - name: cleanup-chaos-resources
      container:
        image: litmuschaos/k8s:latest
        command:
          - sh
          - -c
        args:
          - kubectl delete chaosengine -l workflow_run_id={{workflow.uid}} -n {{workflow.parameters.adminModeNamespace}}
EOF

# Fetch Project ID
echo "🔍 Fetching Project ID..."
# We use jq to parse the JSON output robustly.
PROJECT_ID=$(litmusctl get projects --output json | jq -r '.projects[] | select(.name=="Self-Chaos") | .projectID')
echo "   Project ID: $PROJECT_ID"

if [ -z "$PROJECT_ID" ]; then
    echo "❌ Error: Could not fetch Project ID. Exiting."
    exit 1
fi
export PROJECT_ID

# Fetch Chaos Infra ID for the experiment
echo "🔍 Fetching Chaos Infra ID..."
# Output format: ID NAME STATUS ...
INFRA_ID=$(litmusctl get chaos-infra --project-id "$PROJECT_ID" | awk 'NR==2 {print $1}')
echo "   Infra ID: $INFRA_ID"

# Fetch Experiment ID
# User confirmed that Experiment ID is the same as the workflow name.
EXPERIMENT_ID="pod-delete-test"
echo "   Experiment ID: $EXPERIMENT_ID"

echo "🚀 Creating/Saving Chaos Experiment..."
 litmusctl create chaos-experiment \
    -f /tmp/pod-delete-workflow.yaml \
    --project-id "$PROJECT_ID" \
    --chaos-infra-id "$INFRA_ID" \
    --description "Automated pod delete test"; 
    echo "✅ Experiment created successfully."

    litmusctl save chaos-experiment \
        -f /tmp/pod-delete-workflow.yaml \
        --project-id "$PROJECT_ID" \
        --chaos-infra-id "$INFRA_ID" \
        --description "Automated pod delete test" || echo "⚠️  Save failed (check duplicate key error if unchanged)"

# if [ -n "$EXPERIMENT_ID" ]; then
#     echo "🚀 Triggering Chaos Experiment Run..."
#     echo "DEBUG: Project ID: $PROJECT_ID"
#     echo "DEBUG: Experiment ID: $EXPERIMENT_ID"
#     litmusctl run chaos-experiment --project-id "$PROJECT_ID" --experiment-id "$EXPERIMENT_ID" || echo "⚠️  Run trigger failed"
# fi

echo "📋 Listing Chaos Experiment Runs..."
litmusctl get chaos-experiment-runs --project-id "$PROJECT_ID" || true

echo ""
echo "✅ Chaos Experiment Setup Complete!"
echo ""
echo "📊 You can now run the experiment from the Litmus Portal:"
echo "   1. Visit: http://litmus.${INGRESS_IP}.nip.io"
echo "   2. Go to: Chaos Experiments"
echo "   3. Find: pod-delete-test"
echo "   4. Click: Run"
echo ""
echo "🎯 The experiment will test resilience by deleting pods in the staging namespace."
echo ""


