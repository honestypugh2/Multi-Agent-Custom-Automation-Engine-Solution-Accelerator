param(
    [Parameter(Mandatory=$true)]
    [Alias("g")]
    [string]$ResourceGroup,

    [Parameter(Mandatory=$false)]
    [Alias("t")]
    [string]$ImageTag = "latest",

    [Parameter(Mandatory=$false)]
    [Alias("h")]
    [switch]$Help
)

# Error handling
$ErrorActionPreference = "Stop"

# Color output functions
function Write-Status {
    param([string]$Message)
    Write-Host "[INFO] $Message" -ForegroundColor Blue
}

function Write-Success {
    param([string]$Message)
    Write-Host "[SUCCESS] $Message" -ForegroundColor Green
}

function Write-Error {
    param([string]$Message)
    Write-Host "[ERROR] $Message" -ForegroundColor Red
}

# Help function
function Show-Help {
    Write-Host "Usage: .\build_and_push_after_acr.ps1 -ResourceGroup <resource-group> [-ImageTag <image-tag>]"
    Write-Host "  -ResourceGroup, -g: Azure resource group name (required)"
    Write-Host "  -ImageTag, -t: Image tag (default: latest)"
    Write-Host "  -Help, -h: Show this help message"
    exit 0
}

if ($Help) {
    Show-Help
}

if ([string]::IsNullOrEmpty($ResourceGroup)) {
    Write-Error "Resource group is required. Use -ResourceGroup option."
    exit 1
}

Write-Status "=== STEP 2: BUILD AND PUSH CONTAINER IMAGES ==="
Write-Status "Resource Group: $ResourceGroup"
Write-Status "Image Tag: $ImageTag"

try {
    # Check Azure authentication
    Write-Status "Checking Azure authentication..."
    $account = az account show 2>$null | ConvertFrom-Json
    if (-not $account) {
        Write-Error "You are not logged into Azure CLI. Please run 'az login' first."
        exit 1
    }

    # Find the Container Registry deployed in step 1
    Write-Status "Finding Container Registry in resource group: $ResourceGroup"
    $acrList = az acr list --resource-group $ResourceGroup --query "[0].name" -o tsv 2>$null

    if ([string]::IsNullOrEmpty($acrList) -or $acrList -eq "null") {
        Write-Error "No Container Registry found in resource group: $ResourceGroup"
        Write-Error "Make sure you have deployed the ACR first using deploy-acr-only.bicep"
        exit 1
    }

    $ACR_NAME = $acrList
    Write-Success "Found Container Registry: $ACR_NAME"

    # Get ACR login server
    $ACR_LOGIN_SERVER = az acr show --name $ACR_NAME --resource-group $ResourceGroup --query "loginServer" -o tsv
    Write-Success "ACR Login Server: $ACR_LOGIN_SERVER"

    # Authenticate to ACR
    Write-Status "Authenticating to Azure Container Registry..."
    az acr login --name $ACR_NAME
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Failed to authenticate to ACR"
        exit 1
    }

    # Check Docker
    Write-Status "Checking Docker..."
    docker info >$null 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Docker is not running. Please start Docker and try again."
        exit 1
    }

    # Build and push backend
    Write-Status "Building and pushing backend image..."
    $BACKEND_IMAGE = "$ACR_LOGIN_SERVER/macaebackend:$ImageTag"

    docker build -t $BACKEND_IMAGE ./src/backend
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Failed to build backend image"
        exit 1
    }

    docker push $BACKEND_IMAGE
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Failed to push backend image"
        exit 1
    }
    Write-Success "Backend image pushed: $BACKEND_IMAGE"

    # Build and push frontend
    Write-Status "Building and pushing frontend image..."
    $FRONTEND_IMAGE = "$ACR_LOGIN_SERVER/macaefrontend:$ImageTag"

    docker build -t $FRONTEND_IMAGE ./src/frontend
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Failed to build frontend image"
        exit 1
    }

    docker push $FRONTEND_IMAGE
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Failed to push frontend image"
        exit 1
    }
    Write-Success "Frontend image pushed: $FRONTEND_IMAGE"

    # Verify images
    Write-Status "Verifying pushed images..."
    az acr repository list --name $ACR_NAME --output table
    az acr repository show-tags --name $ACR_NAME --repository "macaebackend" --output table
    az acr repository show-tags --name $ACR_NAME --repository "macaefrontend" --output table

    Write-Success "=== STEP 2 COMPLETED SUCCESSFULLY ==="
    Write-Success "Images ready for Container Apps deployment:"
    Write-Success "  Backend:  $BACKEND_IMAGE"
    Write-Success "  Frontend: $FRONTEND_IMAGE"
    Write-Success "Ready for Step 3: Deploy Container Apps"

} catch {
    Write-Error "An error occurred: $($_.Exception.Message)"
    exit 1
}