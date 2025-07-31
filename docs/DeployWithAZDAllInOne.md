# Deploying with AZD: All-in-One

> [!IMPORTANT]
> Make sure you have completed the deployment steps at [VS Code Dev Containers](./DeploymentGuide.md#vs-code-dev-containers) before proceeding.

🗒️This uses `infra/deploy_acr_only.bicep` and `infra/deploy_container_apps_only.bicep` .

The All-in-One approach is a 3-Step deployment in one script that handles Deploy ACR only, build and push images to ACR, and Deploy Container Apps (rest of the deployment). This breaks up the `infra/main.bicep` into two bicep templates. *Note that `infra/main.bicep` is not used for All-in-One deployment.* Deploy ACR only at `infra/deploy_acr_only.bicep` and Deploy Container Apps at `infra/deploy_container_apps_only.bicep`.

Once you've opened the project in [Codespaces](./DeploymentGuide.md#github-codespaces), [Dev Containers](./DeploymentGuide.md#vs-code-dev-containers), or [locally](./DeploymentGuide.md#local-environment), you can deploy it to Azure by following these steps:

1. Login to Azure:

   ```bash
   azd auth login
   ```

   OR

   ```bash
   az login
   ```

    To authenticate with Azure Developer CLI (`azd`), use the following command with your **Tenant ID**:

   ```bash
   azd auth login --tenant-id <tenant-id>
   ```

2. Make scripts executable.
    ```bash
    chmod +x infra/scripts/build_and_push_after_acr.sh
    chmod +x infra/scripts/deploy_workflow.sh
    ```
3. Set environment variables:
    ```bash
    export AZURE_ENV_NAME=<env-name>
    export AZURE_LOCATION=<location>
    export AZURE_RESOURCE_GROUP=<resource-group-name>
    export AZURE_ENV_OPENAI_LOCATION=<openai-location>
    ```
4. Run the complete workflow
    ```bash
    ./infra/scripts/deploy_workflow.sh
    ```
    Or, run each step individually:

    ```bash
    # Step 1: Deploy ACR
    az deployment group create \
      --resource-group "$AZURE_RESOURCE_GROUP" \
      --template-file "infra/deploy_acr_only.bicep" \
      --parameters "infra/deploy_acr_only.parameters.json"
    ```

    ```bash
    # Step 2: Build and push images
    ./infra/scripts/build_and_push_after_acr.sh -g "$AZURE_RESOURCE_GROUP" -t "latest"
    ```

    ```bash
    # Step 3: Deploy Container Apps
    az deployment group create \
      --resource-group "$AZURE_RESOURCE_GROUP" \
      --template-file "infra/deploy_container_apps_only.bicep" \
      --parameters "infra/deploy_container_apps_only.parameters.json"
    ```

    You could even list out the parameters:

    ```bash
    az deployment group create \
      --resource-group "$RESOURCE_GROUP" \
      --template-file "infra/deploy_container_apps_only.bicep" \
      --parameters environmentName="$ENV_NAME" \
                  solutionLocation="$LOCATION" \
                  enableTelemetry="$ENABLE_TELEMETRY" \
                  imageTag="$IMAGE_TAG"
    ```

This workflow ensures:
- Step 1: ACR is available before building images
- Step 2: Images are pushed to ACR before Container Apps deployment
- Step 3: Container Apps can successfully pull images from ACR