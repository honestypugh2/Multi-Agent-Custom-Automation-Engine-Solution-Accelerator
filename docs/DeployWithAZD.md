# Deploying with AZD

> [!IMPORTANT]
> Make sure you have completed the deployment steps at [VS Code Dev Containers](./DeploymentGuide.md#vs-code-dev-containers) before proceeding.

🗒️This uses `infra/main.bicep`.

Once you've opened the project in [Codespaces](./DeploymentGuide.md#github-codespaces), [VS Code Dev Containers](./DeploymentGuide.md#vs-code-dev-containers), or [locally](./DeploymentGuide.md#local-environment), you can deploy it to Azure by following these steps:

1. Login to Azure:

   ```bash
   azd auth login
   ```

   #### To authenticate with Azure Developer CLI (`azd`), use the following command with your **Tenant ID**:

   ```bash
   azd auth login --tenant-id <tenant-id>
   ```

2. Provision and deploy all the resources:

   ```bash
   azd up
   ```

3. Provide an `azd` environment name (e.g., "macaeapp").
4. Select a subscription from your Azure account and choose a location that has quota for all the resources.

   - This deployment will take _4-6 minutes_ to provision the resources in your account and set up the solution with sample data.
   - If you encounter an error or timeout during deployment, changing the location may help, as there could be availability constraints for the resources.

    **⚠️ Warning:** This current deployment will return a **deployment error** because the Container App is trying to pull a container image that does not exist in your Azure Container Registry. This means that the Bicep template is set to use ACR but the container images have not been built and pushed to the registry yet. This deployment uses Azure Container Registry (ACR) as the DEFAULT container registry. The creation of ACR can be found in `infra/main.bicep`.

    Before moving to step 5, we will manually build and push the images to ACR. In your terminal (where the deployment failed), execute the following code. Make sure to check your deployment in Azure Portal and retrieve the RESOURCE_GROUP, ACR_NAME, ACR_LOGIN_SERVER, and IMAGE_TAG.

    ```bash
    # Login to Azure
    az login

    # Authenticate first
    az acr login --name <acr-name>

    # Build and push backend image
    docker build -t <acr-login-server>/macaebackend:<image-tag> ./src/backend
    docker push <acr-name>.azurecr.io/macaebackend:<image-tag>

    # Build and push frontend image
    docker build -t <acr-login-server>/macaefrontend:<image-tag> ./src/frontend
    docker push <acr-login-server>/macaefrontend:<image-tag>

    ```

    **OR** if you would rather run the code above using a shell script,

    ```bash
    chmod +x infra/scripts/build_and_push_after_acr.sh

    # Run the build and push script
    ./infra/scripts/build_and_push_after_acr.sh -g "$RESOURCE_GROUP" -t "$IMAGE_TAG"
    ```

    Once the images are successfully pushed to ACR, continue the Provision and deploy all resources from Step 2.

    ```bash
    azd up
    ```

5. Once the deployment has completed successfully, open the [Azure Portal](https://portal.azure.com/), go to the deployed resource group, find the App Service, and get the app URL from `Default domain`.

6. If you are done trying out the application, you can delete the resources by running `azd down` or `azd down --purge --force`.