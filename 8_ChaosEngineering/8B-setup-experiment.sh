#!/bin/bash

# ==============================================================================
# 8B - Setup Litmus Chaos Experiment
# ==============================================================================
# Purpose: Create Project, Environment, Agent, and Test Workflow
# Prerequisites: Run 8-deploy-litmus.sh first
# ==============================================================================

set -e

# Step 10: Select Chaos Workflow
echo "Step 10: Selecting Chaos Workflow..."

WORKFLOW_FILE=""

# Check if an argument is provided
if [ -n "$1" ]; then
    WORKFLOW_FILE="$1"
else
    # List available YAML files and ask user to select
    echo "Available Workflow Files:"
    files=(*.yaml *.yml)
    if [ ${#files[@]} -eq 0 ]; then
        echo "❌ No YAML files found in current directory."
        exit 1
    fi

    PS3="Please select a workflow file (enter number): "
    select file in "${files[@]}"; do
        if [ -n "$file" ]; then
            WORKFLOW_FILE="$file"
            break
        else
            echo "Invalid selection. Please try again."
        fi
    done
fi

if [ ! -f "$WORKFLOW_FILE" ]; then
    echo "❌ Error: File '$WORKFLOW_FILE' not found."
    exit 1
fi

echo "✅ Selected Workflow File: $WORKFLOW_FILE"

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

# Extract Experiment ID (metadata.name) from the YAML file
echo "🔍 Extracting Experiment ID from $WORKFLOW_FILE..."
# Assuming metadata.name is in the first few lines. Using grep/awk to extract.
# We look for "name:" under "metadata:" block.
# This is a simple extraction, assuming standard formatting.
EXPERIMENT_ID=$(grep -A 5 "^metadata:" "$WORKFLOW_FILE" | grep "^  name:" | head -n 1 | awk '{print $2}')

if [ -z "$EXPERIMENT_ID" ]; then
    echo "❌ Error: Could not extract 'metadata.name' from $WORKFLOW_FILE."
    exit 1
fi

echo "   Experiment ID: $EXPERIMENT_ID"

echo "🚀 Creating/Saving Chaos Experiment..."
 litmusctl create chaos-experiment \
    -f "$WORKFLOW_FILE" \
    --project-id "$PROJECT_ID" \
    --chaos-infra-id "$INFRA_ID" \
    --description "Automated chaos experiment: $EXPERIMENT_ID"; 
    echo "✅ Experiment created successfully."

    litmusctl save chaos-experiment \
        -f "$WORKFLOW_FILE" \
        --project-id "$PROJECT_ID" \
        --chaos-infra-id "$INFRA_ID" \
        --description "Automated chaos experiment: $EXPERIMENT_ID" || echo "⚠️  Save failed (check duplicate key error if unchanged)"

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
echo "   3. Find: $EXPERIMENT_ID"
echo "   4. Click: Run"
echo ""
echo "🎯 The experiment is ready."
echo ""

