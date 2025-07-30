param(
    [Parameter(Mandatory=$false)]
    [string]$ResourceGroup = $env:AZURE_RESOURCE_GROUP,

    [Parameter(Mandatory=$false)]
    [string]$Location = $env:AZURE_LOCATION,

    [Parameter(Mandatory=$false)]
    [string]$EnvironmentName = $env:AZURE_ENV_NAME,

    [Parameter(Mandatory=$false)]
    [string]$ImageTag = $env:AZURE_ENV_IMAGE_TAG,

    [Parameter(Mandatory=$false)]
    [string]$EnableTelemetry = $env:AZURE_ENV_ENABLE_TELEMETRY,

    [Parameter(Mandatory=$false)]
    [switch]$Help
)

# Error handling
$ErrorActionPreference = "Stop"

# Set default values if not provided via parameters or environment variables
if ([string]::IsNullOrEmpty($ResourceGroup)) { $ResourceGroup = "rg-macae-demo" }
if ([string]::IsNullOrEmpty($Location)) { $Location = "eastus2" }
if ([string]::IsNullOrEmpty($EnvironmentName)) { $EnvironmentName = "demo" }
if ([string]::IsNullOrEmpty($ImageTag)) { $ImageTag = "latest" }
if ([string]::IsNullOrEmpty($EnableTelemetry)) { $EnableTelemetry = "true" }

# Color output functions
function Write-Step {
    param([string]$Message)
    Write-Host "=== $Message ===" -ForegroundColor Blue
}

function Write-Success {
    param([string]$Message)
    Write-Host "✅ $Message" -ForegroundColor Green
}

function Write-Info {
    param([string]$Message)
    Write-Host "ℹ️  $Message" -ForegroundColor Yellow
}

function Write-Error {
    param([string]$Message)
    Write-Host "❌ $Message" -ForegroundColor Red
}

# Help function
function Show-Help {
    Write-Host "Usage: .\deploy_workflow.ps1 [parameters]"
    Write-Host ""
    Write-Host "Parameters:"
    Write-Host "  -ResourceGroup: Azure resource group name (default: rg-macae-demo or AZURE_RESOURCE_GROUP env var)"
    Write-Host "  -Location: Azure location (default: eastus2 or AZURE_LOCATION env var)"
    Write-Host "  -EnvironmentName: Environment name (default: demo or AZURE_ENV_NAME env var)"
    Write-Host "  -ImageTag: Container image tag (default: latest or AZURE_ENV_IMAGE_TAG env var)"
    Write-Host "  -EnableTelemetry: Enable telemetry (default: true or AZURE_ENV_ENABLE_TELEMETRY env var)"
    Write-Host "  -Help: Show this help message"
    Write-Host ""
    Write-Host "Environment Variables:"
    Write-Host "  AZURE_RESOURCE_GROUP"
    Write-Host "  AZURE_LOCATION"
    Write-Host "  AZURE_ENV_NAME"
    Write-Host "  AZURE_ENV_IMAGE_TAG"
    Write-Host "  AZURE_ENV_ENABLE_TELEMETRY"
    exit 0
}

if ($Help) {
    Show-Help
}

# Check if we're in the right directory
if (-not (Test-Path "infra/deploy_acr_only.bicep")) {
    Write-Error "Script must be run from the repository root directory"
    exit 1
}

Write-Step "MULTI-AGENT CUSTOM AUTOMATION ENGINE - 3-STEP DEPLOYMENT"

Write-Info "Configuration:"
Write-Info "  Resource Group: $ResourceGroup"
Write-Info "  Location: $Location"
Write-Info "  Environment: $EnvironmentName"
Write-Info "  Image Tag: $ImageTag"
Write-Info "  Enable Telemetry: $EnableTelemetry"

try {
    # Create resource group if it doesn't exist
    Write-Step "STEP 0: CREATING RESOURCE GROUP"
    az group create --name $ResourceGroup --location $Location --output table --only-show-errors
    Write-Success "Resource group ready"

    # Step 1: Deploy Container Registry
    Write-Step "STEP 1: DEPLOYING CONTAINER REGISTRY"
    $STEP1_DEPLOYMENT_NAME = "step1-acr-$(Get-Date -Format 'yyyyMMdd-HHmmss')"

    az deployment group create `
        --resource-group $ResourceGroup `
        --template-file "infra/deploy_acr_only.bicep" `
        --parameters environmentName=$EnvironmentName `
                     solutionLocation=$Location `
                     enableTelemetry=$EnableTelemetry `
                     imageTag=$ImageTag `
        --name $STEP1_DEPLOYMENT_NAME `
        --output table `
        --only-show-errors

    if ($LASTEXITCODE -ne 0) {
        Write-Error "Container Registry deployment failed"
        exit 1
    }

    Write-Success "Container Registry deployed successfully"

    # Get outputs from Step 1
    Write-Info "Retrieving Container Registry information..."
    $ACR_NAME = az deployment group show `
        --resource-group $ResourceGroup `
        --name $STEP1_DEPLOYMENT_NAME `
        --query "properties.outputs.containerRegistryName.value" -o tsv `
        --only-show-errors

    $ACR_LOGIN_SERVER = az deployment group show `
        --resource-group $ResourceGroup `
        --name $STEP1_DEPLOYMENT_NAME `
        --query "properties.outputs.containerRegistryLoginServer.value" -o tsv `
        --only-show-errors

    $SOLUTION_PREFIX = az deployment group show `
        --resource-group $ResourceGroup `
        --name $STEP1_DEPLOYMENT_NAME `
        --query "properties.outputs.solutionPrefix.value" -o tsv `
        --only-show-errors

    Write-Info "ACR Name: $ACR_NAME"
    Write-Info "ACR Login Server: $ACR_LOGIN_SERVER"
    Write-Info "Solution Prefix: $SOLUTION_PREFIX"

    # Step 2: Build and Push Images
    Write-Step "STEP 2: BUILDING AND PUSHING CONTAINER IMAGES"

    # Check if PowerShell script exists, otherwise fallback to shell script
    $buildScript = "infra/scripts/build_and_push_after_acr.ps1"
    if (Test-Path $buildScript) {
        & $buildScript -ResourceGroup $ResourceGroup -ImageTag $ImageTag
    } else {
        # Fallback to shell script (requires WSL or Git Bash on Windows)
        Write-Info "PowerShell script not found, using shell script..."
        if (Get-Command "bash" -ErrorAction SilentlyContinue) {
            bash "./infra/scripts/build_and_push_after_acr.sh" -g $ResourceGroup -t $ImageTag
        } else {
            Write-Error "Neither PowerShell script nor bash is available. Please ensure build_and_push_after_acr.ps1 exists or install WSL/Git Bash."
            exit 1
        }
    }

    if ($LASTEXITCODE -ne 0) {
        Write-Error "Container image build and push failed"
        exit 1
    }

    Write-Success "Container images built and pushed successfully"

    # Step 3: Deploy Container Apps
    Write-Step "STEP 3: DEPLOYING CONTAINER APPS"
    $STEP3_DEPLOYMENT_NAME = "step3-apps-$(Get-Date -Format 'yyyyMMdd-HHmmss')"

    az deployment group create `
        --resource-group $ResourceGroup `
        --template-file "infra/deploy_container_apps_only.bicep" `
        --parameters environmentName=$EnvironmentName `
                     solutionLocation=$Location `
                     enableTelemetry=$EnableTelemetry `
                     imageTag=$ImageTag `
        --name $STEP3_DEPLOYMENT_NAME `
        --output table `
        --only-show-errors

    if ($LASTEXITCODE -ne 0) {
        Write-Error "Container Apps deployment failed"
        exit 1
    }

    Write-Success "Container Apps deployed successfully"

    # Get the Container App URL
    Write-Info "Retrieving Container App information..."
    $CONTAINER_APP_FQDN = az deployment group show `
        --resource-group $ResourceGroup `
        --name $STEP3_DEPLOYMENT_NAME `
        --query "properties.outputs.containerAppFqdn.value" -o tsv `
        --only-show-errors 2>$null

    if ([string]::IsNullOrEmpty($CONTAINER_APP_FQDN)) {
        $CONTAINER_APP_FQDN = ""
    }

    Write-Step "DEPLOYMENT COMPLETED SUCCESSFULLY"

    if (-not [string]::IsNullOrEmpty($CONTAINER_APP_FQDN)) {
        Write-Success "Container App URL: https://$CONTAINER_APP_FQDN"
    } else {
        Write-Info "Container App deployed. Check Azure portal for the application URL."
    }

    Write-Info "Resource Group: $ResourceGroup"
    Write-Info "Solution Prefix: $SOLUTION_PREFIX"
    Write-Info "You can now access your Multi-Agent Custom Automation Engine!"

    # Display useful next steps
    Write-Step "NEXT STEPS"
    Write-Info "1. Check the Azure portal to verify all resources are deployed"
    Write-Info "2. Access the Container App using the URL above"
    Write-Info "3. Monitor the application logs using Azure Container Apps portal"
    Write-Info "4. To clean up resources: az group delete --name '$ResourceGroup' --yes"

} catch {
    Write-Error "An error occurred: $($_.Exception.Message)"
    exit 1
}