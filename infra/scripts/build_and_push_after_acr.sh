#!/bin/bash
# filepath: /workspaces/Multi-Agent-Custom-Automation-Engine-Solution-Accelerator/scripts/build_and_push_after_acr.sh

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Default values
RESOURCE_GROUP=""
IMAGE_TAG="latest"

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -g|--resource-group)
            RESOURCE_GROUP="$2"
            shift 2
            ;;
        -t|--tag)
            IMAGE_TAG="$2"
            shift 2
            ;;
        -h|--help)
            echo "Usage: $0 -g <resource-group> [-t <image-tag>]"
            echo "  -g, --resource-group: Azure resource group name (required)"
            echo "  -t, --tag: Image tag (default: latest)"
            exit 0
            ;;
        *)
            print_error "Unknown option: $1"
            exit 1
            ;;
    esac
done

if [[ -z "$RESOURCE_GROUP" ]]; then
    print_error "Resource group is required. Use -g option."
    exit 1
fi

print_status "=== STEP 2: BUILD AND PUSH CONTAINER IMAGES ==="
print_status "Resource Group: $RESOURCE_GROUP"
print_status "Image Tag: $IMAGE_TAG"

# Check Azure authentication
print_status "Checking Azure authentication..."
az account show >/dev/null 2>&1
if [[ $? -ne 0 ]]; then
    print_error "You are not logged into Azure CLI. Please run 'az login' first."
    exit 1
fi

# Find the Container Registry deployed in step 1
print_status "Finding Container Registry in resource group: $RESOURCE_GROUP"
ACR_NAME=$(az acr list --resource-group "$RESOURCE_GROUP" --query "[0].name" -o tsv 2>/dev/null)

if [[ -z "$ACR_NAME" || "$ACR_NAME" == "null" ]]; then
    print_error "No Container Registry found in resource group: $RESOURCE_GROUP"
    print_error "Make sure you have deployed the ACR first using deploy-acr-only.bicep"
    exit 1
fi

print_success "Found Container Registry: $ACR_NAME"

# Get ACR login server
ACR_LOGIN_SERVER=$(az acr show --name "$ACR_NAME" --resource-group "$RESOURCE_GROUP" --query "loginServer" -o tsv)
print_success "ACR Login Server: $ACR_LOGIN_SERVER"

# Authenticate to ACR
print_status "Authenticating to Azure Container Registry..."
az acr login --name "$ACR_NAME"
if [[ $? -ne 0 ]]; then
    print_error "Failed to authenticate to ACR"
    exit 1
fi

# Check Docker
print_status "Checking Docker..."
docker info >/dev/null 2>&1
if [[ $? -ne 0 ]]; then
    print_error "Docker is not running. Please start Docker and try again."
    exit 1
fi

# Build and push backend
print_status "Building and pushing backend image..."
BACKEND_IMAGE="${ACR_LOGIN_SERVER}/macaebackend:${IMAGE_TAG}"
docker build --platform linux/amd64 -t "$BACKEND_IMAGE" ./src/backend

if [[ $? -ne 0 ]]; then
    print_error "Failed to build backend image"
    exit 1
fi

docker push "$BACKEND_IMAGE"
if [[ $? -ne 0 ]]; then
    print_error "Failed to push backend image"
    exit 1
fi
print_success "Backend image pushed: $BACKEND_IMAGE"

# Build and push frontend
print_status "Building and pushing frontend image..."
FRONTEND_IMAGE="${ACR_LOGIN_SERVER}/macaefrontend:${IMAGE_TAG}"
docker build --platform linux/amd64 -t "$FRONTEND_IMAGE" ./src/frontend
if [[ $? -ne 0 ]]; then
    print_error "Failed to build frontend image"
    exit 1
fi

docker push "$FRONTEND_IMAGE"
if [[ $? -ne 0 ]]; then
    print_error "Failed to push frontend image"
    exit 1
fi
print_success "Frontend image pushed: $FRONTEND_IMAGE"

# Verify images
print_status "Verifying pushed images..."
az acr repository list --name "$ACR_NAME" --output table
az acr repository show-tags --name "$ACR_NAME" --repository "macaebackend" --output table
az acr repository show-tags --name "$ACR_NAME" --repository "macaefrontend" --output table

print_success "=== STEP 2 COMPLETED SUCCESSFULLY ==="
print_success "Images ready for Container Apps deployment:"
print_success "  Backend:  $BACKEND_IMAGE"
print_success "  Frontend: $FRONTEND_IMAGE"
print_success "Ready for Step 3: Deploy Container Apps"