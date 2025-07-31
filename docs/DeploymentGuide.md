# Deployment Guide

⭐ This guide supports Azure Container Registry (ACR) for image container registry.

## **Pre-requisites**

To deploy this solution accelerator, ensure you have access to an [Azure subscription](https://azure.microsoft.com/free/) with the necessary permissions to create **resource groups, resources, app registrations, and assign roles at the resource group level**. This should include Contributor role at the subscription level and Role Based Access Control role on the subscription and/or resource group level. Follow the steps in [Azure Account Set Up](../docs/AzureAccountSetUp.md).

Check the [Azure Products by Region](https://azure.microsoft.com/en-us/explore/global-infrastructure/products-by-region/?products=all&regions=all) page and select a **region** where the following services are available:

- [Azure AI Foundry](https://learn.microsoft.com/en-us/azure/ai-foundry/)
- [Azure Container Apps](https://learn.microsoft.com/en-us/azure/container-apps/)
- [Azure Container Registry](https://learn.microsoft.com/en-us/azure/container-registry/)
- [Azure Cosmos DB](https://learn.microsoft.com/en-us/azure/cosmos-db/)
- [Azure Key Vault](https://learn.microsoft.com/en-us/azure/key-vault/)
- [Azure AI Search](https://learn.microsoft.com/en-us/azure/search/)
- [GPT Model Capacity](https://learn.microsoft.com/en-us/azure/ai-services/openai/concepts/models)

Here are some example regions where the services are available: East US, East US2, Japan East, UK South, Sweden Central.

### **Important Note for PowerShell Users**

If you encounter issues running PowerShell scripts due to the policy of not being digitally signed, you can temporarily adjust the `ExecutionPolicy` by running the following command in an elevated PowerShell session:

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
```

This will allow the scripts to run for the current session without permanently changing your system's policy.

## Deployment Options & Steps

### Sandbox or WAF Aligned Deployment Options

The [`infra`](../infra) folder of the Multi Agent Solution Accelerator contains the [`main.bicep`](../infra/main.bicep) Bicep script, which defines all Azure infrastructure components for this solution.

When running `azd up`, you’ll now be prompted to choose between a **WAF-aligned configuration** and a **sandbox configuration** using a simple selection:

- A **sandbox environment** — ideal for development and proof-of-concept scenarios, with minimal security and cost controls for rapid iteration.

- A **production deployments environment**, which applies a [Well-Architected Framework (WAF) aligned](https://learn.microsoft.com/en-us/azure/well-architected/) configuration. This option enables additional Azure best practices for reliability, security, cost optimization, operational excellence, and performance efficiency, such as:
  - Enhanced network security (e.g., Network protection with private endpoints)
  - Stricter access controls and managed identities
  - Logging, monitoring, and diagnostics enabled by default
  - Resource tagging and cost management recommendations

**How to choose your deployment configuration:**

When prompted during `azd up`:

![useWAFAlignedArchitecture](images/macae_waf_prompt.png)

- Select **`true`** to deploy a **WAF-aligned, production-ready environment**
- Select **`false`** to deploy a **lightweight sandbox/dev environment**

> [!TIP]
> Always review and adjust parameter values (such as region, capacity, security settings and log analytics workspace configuration) to match your organization’s requirements before deploying. For production, ensure you have sufficient quota and follow the principle of least privilege for all identities and role assignments.

> To reuse an existing Log Analytics workspace, update the existingWorkspaceResourceId field under the logAnalyticsWorkspaceConfiguration parameter in the .bicep file with the resource ID of your existing workspace.
For example:
```
param logAnalyticsWorkspaceConfiguration = {
  dataRetentionInDays: 30
  existingWorkspaceResourceId: '/subscriptions/<subscription-id>/resourceGroups/<resource-group>/providers/Microsoft.OperationalInsights/workspaces/<workspace-name>'
}
```
> [!IMPORTANT]
> The WAF-aligned configuration is under active development. More Azure Well-Architected recommendations will be added in future updates.

### Deployment Steps

Pick from the options below to see step-by-step instructions for GitHub Codespaces, VS Code Dev Containers, Local Environments, and Bicep deployments.

| [![Open in GitHub Codespaces](https://github.com/codespaces/badge.svg)](https://codespaces.new/microsoft/Multi-Agent-Custom-Automation-Engine-Solution-Accelerator) | [![Open in Dev Containers](https://img.shields.io/static/v1?style=for-the-badge&label=Dev%20Containers&message=Open&color=blue&logo=visualstudiocode)](https://vscode.dev/redirect?url=vscode://ms-vscode-remote.remote-containers/cloneInVolume?url=https://github.com/microsoft/Multi-Agent-Custom-Automation-Engine-Solution-Accelerator) |
| ------------------------------------------------------------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |

### 💻 GitHub Codespaces

<details>
  <summary><b>Deploy in GitHub Codespaces</b></summary>

You can run this solution using GitHub Codespaces. The button will open a web-based VS Code instance in your browser:

1. Open the solution accelerator (this may take several minutes):

   [![Open in GitHub Codespaces](https://github.com/codespaces/badge.svg)](https://codespaces.new/microsoft/Multi-Agent-Custom-Automation-Engine-Solution-Accelerator)

2. Accept the default values on the create Codespaces page.
3. Open a terminal window if it is not already open.
4. Continue with the deployment steps using **one** of the options below:
- [Deploying with AZD](./DeployWithAZD.md#deploying-with-azd)
- [Deploying with AZD: All-in-One](./DeployWithAZDAllInOne.md#deploying-with-azd-all-in-one)

</details>

### ☁️ VS Code Dev Containers
Select one of the VS Code Dev Containers options below to complete your deployment.

<details>
  <summary><b>Deploy in VS Code Dev Containers: Quick Deploy</b></summary>

You can run this solution in VS Code Dev Containers, which will open the project in your local VS Code using the [Dev Containers extension](https://marketplace.visualstudio.com/items?itemName=ms-vscode-remote.remote-containers):

1. Start Docker Desktop (install it if not already installed).
2. Open the project:

   [![Open in Dev Containers](https://img.shields.io/static/v1?style=for-the-badge&label=Dev%20Containers&message=Open&color=blue&logo=visualstudiocode)](https://vscode.dev/redirect?url=vscode://ms-vscode-remote.remote-containers/cloneInVolume?url=https://github.com/microsoft/Multi-Agent-Custom-Automation-Engine-Solution-Accelerator)

3. In the VS Code window that opens, once the project files show up (this may take several minutes), open a terminal window.

4. Continue with the deployment steps using **one** of the options below:
- [Deploying with AZD](./DeployWithAZD.md#deploying-with-azd)
- [Deploying with AZD: All-in-One](./DeployWithAZDAllInOne.md#deploying-with-azd-all-in-one)

</details>

<details>
  <summary><b>Deploy in VS Code Dev Containers: Manual</b></summary>

The easiest way to run this accelerator is in a VS Code Dev Containers, which will open the project in your local VS Code using the [Dev Containers extension](https://marketplace.visualstudio.com/items?itemName=ms-vscode-remote.remote-containers).

The solution contains a [development container](https://code.visualstudio.com/docs/remote/containers) with all the required tooling to develop and deploy the accelerator. To deploy the accelerator using the provided development container you will also need:

- [Visual Studio Code](https://code.visualstudio.com)
- [Remote containers extension for Visual Studio Code](https://marketplace.visualstudio.com/items?itemName=ms-vscode-remote.remote-containers)

❗If you are running this on Windows, we recommend you clone this repository in [WSL](https://code.visualstudio.com/docs/remote/wsl).

1. Start Docker Desktop (install it if not already installed).

2. Clone the project.
    ```bash
    git clone https://github.com/microsoft/Multi-Agent-Custom-Automation-Engine-Solution-Accelerator
    ```

3. Open the cloned repository in Visual Studio Code.

    ```bash
    code .
    ```

4.  In the VS Code window that opens, connect to the development container.

    > [!TIP]
    Visual Studio Code should recognize the available development container and ask you to open the folder using it. For additional details on connecting to remote containers, please see the [Open an existing folder in a container](https://code.visualstudio.com/docs/remote/containers#_quick-start-open-an-existing-folder-in-a-container) quickstart.

    :exclamation: If Visual Studio Code does not recognize the development container or you miss the pop-up where it asks you to open in container, please see [Open a WSL 2 folder in a container on Windows](https://code.visualstudio.com/docs/devcontainers/containers#_open-a-wsl-2-folder-in-a-container-on-windows).

5. Once the project files show up (this may take several minutes), open a terminal window.

6. Continue with the deployment steps using **one** of the options below:
  - [Deploying with AZD](./DeployWithAZD.md#deploying-with-azd)
  - [Deploying with AZD: All-in-One](./DeployWithAZDAllInOne.md#deploying-with-azd-all-in-one)


</details>

### 🏠 Local Environment

<details>
  <summary><b>Deploy in VS Code Dev Containers: Manual</b></summary>

The easiest way to run this accelerator is in a VS Code Dev Containers, which will open the project in your local VS Code using the [Dev Containers extension](https://marketplace.visualstudio.com/items?itemName=ms-vscode-remote.remote-containers).

The solution contains a [development container](https://code.visualstudio.com/docs/remote/containers) with all the required tooling to develop and deploy the accelerator. To deploy the accelerator using the provided development container you will also need:

- [Visual Studio Code](https://code.visualstudio.com)
- [Remote containers extension for Visual Studio Code](https://marketplace.visualstudio.com/items?itemName=ms-vscode-remote.remote-containers)

❗If you are running this on Windows, we recommend you clone this repository in [WSL](https://code.visualstudio.com/docs/remote/wsl).

1. Start Docker Desktop (install it if not already installed).

2. Clone the project.
    ```bash
    git clone https://github.com/microsoft/Multi-Agent-Custom-Automation-Engine-Solution-Accelerator
    ```

3. Open the cloned repository in Visual Studio Code.

    ```bash
    code .
    ```

4.  In the VS Code window that opens, connect to the development container.

    > [!TIP]
    Visual Studio Code should recognize the available development container and ask you to open the folder using it. For additional details on connecting to remote containers, please see the [Open an existing folder in a container](https://code.visualstudio.com/docs/remote/containers#_quick-start-open-an-existing-folder-in-a-container) quickstart.

    :exclamation: If Visual Studio Code does not recognize the development container or you miss the pop-up where it asks you to open in container, please see [Open a WSL 2 folder in a container on Windows](https://code.visualstudio.com/docs/devcontainers/containers#_open-a-wsl-2-folder-in-a-container-on-windows).

5. Once the project files show up (this may take several minutes), open a terminal window.

6. Continue with the deployment steps using **one** of the options below:
  - [Deploying with AZD](./DeployWithAZD.md#deploying-with-azd)
  - [Deploying with AZD: All-in-One](./DeployWithAZDAllInOne.md#deploying-with-azd-all-in-one)


</details>

### 🏠 Local Environment

<details>
  <summary><b>Deploy in your Local Environment</b></summary>

If you're not using one of the above options for opening the project, then you'll need to:

1. Make sure the following tools are installed:

   - [PowerShell](https://learn.microsoft.com/en-us/powershell/scripting/install/installing-powershell?view=powershell-7.5) <small>(v7.0+)</small> - available for Windows, macOS, and Linux.
   - [Azure Developer CLI (azd)](https://aka.ms/install-azd) <small>(v1.15.0+)</small> - version
   - [Python 3.9+](https://www.python.org/downloads/)
   - [Docker Desktop](https://www.docker.com/products/docker-desktop/)
   - [Git](https://git-scm.com/downloads)

2. Clone the repository or download the project code via command-line:

   ```shell
   azd init -t microsoft/Multi-Agent-Custom-Automation-Engine-Solution-Accelerator/
   ```

3. Open the project folder in your terminal or editor.
4. Continue with the deployment steps using **one** of the options below:
  - [Deploying with AZD in a Local Environment](./LocalDeployment.md)
  - [Deploying with AZD: All-in-One](./DeployWithAZDAllInOne.md#deploying-with-azd-all-in-one)

📓 Supporting documentation for deployment and debugging:

  - [Local Deployment and Debugging](./LocalDeploymentandDebugging.md)

</details>

_________

### Deployment Considerations

Consider the following settings during your deployment to modify specific settings:

<details>
  <summary><b>Configurable Deployment Settings</b></summary>

When you start the deployment, most parameters will have **default values**, but you can update the following settings [here](../docs/CustomizingAzdParameters.md):

| **Setting**                    | **Description**                                                                      | **Default value** |
| ------------------------------ | ------------------------------------------------------------------------------------ | ----------------- |
| **Environment Name**           | Used as a prefix for all resource names to ensure uniqueness across environments.    | macae             |
| **Azure Region**               | Location of the Azure resources. Controls where the infrastructure will be deployed. | swedencentral     |
| **OpenAI Deployment Location** | Specifies the region for OpenAI resource deployment.                                 | swedencentral     |
| **Model Deployment Type**      | Defines the deployment type for the AI model (e.g., Standard, GlobalStandard).      | GlobalStandard    |
| **GPT Model Name**             | Specifies the name of the GPT model to be deployed.                                 | gpt-4o            |
| **GPT Model Version**          | Version of the GPT model to be used for deployment.                                 | 2024-08-06        |
| **GPT Model Capacity**          | Sets the GPT model capacity.                                 | 150        |
| **Image Tag**                  | Docker image tag used for container deployments.                                    | latest            |
| **Enable Telemetry**           | Enables telemetry for monitoring and diagnostics.                                    | true              |


</details>

<details>
  <summary><b>[Optional] Quota Recommendations</b></summary>

By default, the **GPT model capacity** in deployment is set to **140k tokens**.

To adjust quota settings, follow these [steps](./AzureGPTQuotaSettings.md).

**⚠️ Warning:** Insufficient quota can cause deployment errors. Please ensure you have the recommended capacity or request additional capacity before deploying this solution.

</details>

<details>

  <summary><b>Reusing an Existing Log Analytics Workspace</b></summary>

  Guide to get your [Existing Workspace ID](/docs/re-use-log-analytics.md)

</details>
