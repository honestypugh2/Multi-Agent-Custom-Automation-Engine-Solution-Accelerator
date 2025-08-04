# Deploying with AZD in a Local Environment

## Requirements:

- Python 3.10 or higher + PIP
- Azure CLI, and an Azure Subscription
- Visual Studio Code IDE

# Local setup

> **Note for macOS Developers**: If you are using macOS on Apple Silicon (ARM64) the DevContainer will **not** work. This is due to a limitation with the Azure Functions Core Tools (see [here](https://github.com/Azure/azure-functions-core-tools/issues/3112)). We recommend using the [Non DevContainer Setup](./NON_DEVCONTAINER_SETUP.md) instructions to run the accelerator locally.

The easiest way to run this accelerator is in a VS Code Dev Containers, which will open the project in your local VS Code using the [Dev Containers extension](https://marketplace.visualstudio.com/items?itemName=ms-vscode-remote.remote-containers):

1. Start Docker Desktop (install it if not already installed)
2. Open the project:
   [![Open in Dev Containers](https://img.shields.io/static/v1?style=for-the-badge&label=Dev%20Containers&message=Open&color=blue&logo=visualstudiocode)](https://vscode.dev/redirect?url=vscode://ms-vscode-remote.remote-containers/cloneInVolume?url=https://github.com/microsoft/Multi-Agent-Custom-Automation-Engine-Solution-Accelerator)

3. In the VS Code window that opens, once the project files show up (this may take several minutes), open a terminal window

# Local Environment Deployment with Azure Container Registry


1. Login to Azure:

   ```shell
   azd auth login
   ```

   #### To authenticate with Azure Developer CLI (`azd`), use the following command with your **Tenant ID**:

   ```sh
   azd auth login --tenant-id <tenant-id>
   ```

1. Provision and deploy all the resources:

   ```shell
   azd up
   ```

1. Provide an `azd` environment name (e.g., "macaeapp").
1. Select a subscription from your Azure account and choose a location that has quota for all the resources. You will also be prompted to select 'useWafAlignedArchitecture' (default to False, indicating a sandbox environment), choose an existing or new resource group and the location for it as well.

   - This deployment will take _4-6 minutes_ to provision the resources in your account and set up the solution with sample data.
   - If you encounter an error or timeout during deployment, changing the location may help, as there could be availability constraints for the resources.

    **⚠️ Warning:** This current deployment will return a **deployment error** because the Container App is trying to pull a container image that does not exist in your Azure Container Registry. This means that the Bicep template is set to use ACR but the container images have not been built and pushed to the registry yet. This deployment uses Azure Container Registry (ACR) as the DEFAULT container registry. The creation of ACR can be found in `infra/main.bicep`. 

    Before moving to step 8, we will manually build and push the images to ACR. In your terminal (where the deployment failed), execute the following code. Make sure to check your deployment in Azure Portal and retrieve the RESOURCE_GROUP, ACR_NAME, ACR_LOGIN_SERVER, and IMAGE_TAG.

    > Note: Please ensure that Docker Desktop is running in the background for this build to avoid getting an error on execution of the following commands.

    ```bash
    # Login to Azure
    az login

    # Authenticate first
    az acr login --name <acr-name>

    # Build and push backend image
    docker build --platform linux/amd64 -t <acr-login-server>/macaebackend:<image-tag> ./src/backend
    docker push <acr-name>.azurecr.io/macaebackend:<image-tag>

    # Build and push frontend image
    docker build --platform linux/amd64 -t <acr-login-server>/macaefrontend:<image-tag> ./src/frontend
    docker push <acr-login-server>/macaefrontend:<image-tag>

    ```

    **OR** if you would rather run the code above using a shell script, update the permissions to make the `build_and_push_after_acr_local.sh` executable and input your values for the resource group and image tag.

    ```bash
    chmod +x infra/scripts/build_and_push_after_acr_local.sh

    # Run the build and push script
    ./infra/scripts/build_and_push_after_acr_local.sh -g "RESOURCE_GROUP" -t "IMAGE_TAG"
    ```

    Once the images are successfully pushed to ACR, continue the Provision and deploy all resources from Step 2.

    ```bash
    azd up
    ```

1. Once the deployment has completed successfully, open the [Azure Portal](https://portal.azure.com/), go to the deployed resource group, find the App Service, and get the app URL from `Default domain`.

1. When you're finished testing the application, you can remove all deployed resources by running `azd down` or use `azd down --purge --force` to force the removal.