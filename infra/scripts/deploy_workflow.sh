#!/bin/bash
# filepath: /workspaces/Multi-Agent-Custom-Automation-Engine-Solution-Accelerator/infra/scripts/deploy_workflow.sh

set -e

# Color codes
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

print_step() {
    echo -e "${BLUE}=== $1 ===${NC}"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_info() {
    echo -e "${YELLOW}ℹ️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

# Check if we're in the right directory
if [[ ! -f "infra/deploy_acr_only.bicep" ]]; then
    print_error "Script must be run from the repository root directory"
    exit 1
fi

# Set default values
RESOURCE_GROUP="${AZURE_RESOURCE_GROUP:-rg-macae-demo}"
LOCATION="${AZURE_LOCATION:-eastus2}"
ENV_NAME="${AZURE_ENV_NAME:-demo}"
IMAGE_TAG="${AZURE_ENV_IMAGE_TAG:-latest}"
ENABLE_TELEMETRY="${AZURE_ENV_ENABLE_TELEMETRY:-true}"

print_step "MULTI-AGENT CUSTOM AUTOMATION ENGINE - 3-STEP DEPLOYMENT"

print_info "Configuration:"
print_info "  Resource Group: $RESOURCE_GROUP"
print_info "  Location: $LOCATION"
print_info "  Environment: $ENV_NAME"
print_info "  Image Tag: $IMAGE_TAG"
print_info "  Enable Telemetry: $ENABLE_TELEMETRY"

# Create resource group if it doesn't exist
print_step "STEP 0: CREATING RESOURCE GROUP"
az group create --name "$RESOURCE_GROUP" --location "$LOCATION" --output table
print_success "Resource group ready"

# Step 1: Deploy Container Registry
print_step "STEP 1: DEPLOYING CONTAINER REGISTRY"
STEP1_DEPLOYMENT_NAME="step1-acr-$(date +%Y%m%d-%H%M%S)"

az deployment group create \
  --resource-group "$RESOURCE_GROUP" \
  --template-file "infra/deploy_acr_only.bicep" \
  --parameters environmentName="$ENV_NAME" \
               solutionLocation="$LOCATION" \
               enableTelemetry="$ENABLE_TELEMETRY" \
               imageTag="$IMAGE_TAG" \
  --name "$STEP1_DEPLOYMENT_NAME" \
  --output table

if [[ $? -ne 0 ]]; then
    print_error "Container Registry deployment failed"
    exit 1
fi

print_success "Container Registry deployed successfully"

# Get outputs from Step 1
print_info "Retrieving Container Registry information..."
ACR_NAME=$(az deployment group show \
  --resource-group "$RESOURCE_GROUP" \
  --name "$STEP1_DEPLOYMENT_NAME" \
  --query "properties.outputs.containerRegistryName.value" -o tsv)

ACR_LOGIN_SERVER=$(az deployment group show \
  --resource-group "$RESOURCE_GROUP" \
  --name "$STEP1_DEPLOYMENT_NAME" \
  --query "properties.outputs.containerRegistryLoginServer.value" -o tsv)

SOLUTION_PREFIX=$(az deployment group show \
  --resource-group "$RESOURCE_GROUP" \
  --name "$STEP1_DEPLOYMENT_NAME" \
  --query "properties.outputs.solutionPrefix.value" -o tsv)

print_info "ACR Name: $ACR_NAME"
print_info "ACR Login Server: $ACR_LOGIN_SERVER"
print_info "Solution Prefix: $SOLUTION_PREFIX"

# Step 2: Build and Push Images
print_step "STEP 2: BUILDING AND PUSHING CONTAINER IMAGES"

# Make sure the script is executable
chmod +x infra/scripts/build_and_push_after_acr.sh

# Run the build and push script
./infra/scripts/build_and_push_after_acr.sh -g "$RESOURCE_GROUP" -t "$IMAGE_TAG"

if [[ $? -ne 0 ]]; then
    print_error "Container image build and push failed"
    exit 1
fi

print_success "Container images built and pushed successfully"

# Step 3: Deploy Container Apps
print_step "STEP 3: DEPLOYING CONTAINER APPS"
STEP3_DEPLOYMENT_NAME="step3-apps-$(date +%Y%m%d-%H%M%S)"

az deployment group create \
  --resource-group "$RESOURCE_GROUP" \
  --template-file "infra/deploy_container_apps_only.bicep" \
  --parameters environmentName="$ENV_NAME" \
               solutionLocation="$LOCATION" \
               enableTelemetry="$ENABLE_TELEMETRY" \
               imageTag="$IMAGE_TAG" \
  --name "$STEP3_DEPLOYMENT_NAME" \
  --output table

if [[ $? -ne 0 ]]; then
    print_error "Container Apps deployment failed"
    exit 1
fi

print_success "Container Apps deployed successfully"

# Get the Container App URL
print_info "Retrieving Container App information..."
CONTAINER_APP_FQDN=$(az deployment group show \
  --resource-group "$RESOURCE_GROUP" \
  --name "$STEP3_DEPLOYMENT_NAME" \
  --query "properties.outputs.containerAppFqdn.value" -o tsv 2>/dev/null || echo "")

print_step "DEPLOYMENT COMPLETED SUCCESSFULLY"

if [[ -n "$CONTAINER_APP_FQDN" ]]; then
    print_success "Container App URL: https://$CONTAINER_APP_FQDN"
else
    print_info "Container App deployed. Check Azure portal for the application URL."
fi

print_info "Resource Group: $RESOURCE_GROUP"
print_info "Solution Prefix: $SOLUTION_PREFIX"
print_info "You can now access your Multi-Agent Custom Automation Engine!"

# Display useful next steps
print_step "NEXT STEPS"
print_info "1. Check the Azure portal to verify all resources are deployed"
print_info "2. Access the Container App using the URL above"
print_info "3. Monitor the application logs using Azure Container Apps portal"
print_info "4. To clean up resources: az group delete --name '$RESOURCE_GROUP' --yes"