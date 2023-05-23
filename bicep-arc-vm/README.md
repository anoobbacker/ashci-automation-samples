# Automation: Azure Marketplace VMs on HCI using Bicep and GitHub Actions!
In this sample, you'll learn how to define creating Azure Marketplace VM images on HCI and creating VMs using those image in GitHub Action and how to deploy your Bicep code by using the workflow.

# Problem 
1. To set up VM images, users manually had to download the operating system images, set up a VM, and create a generalized VM image.
2. To keep track of new updates, such as security patches, bug fixes, and feature enhancements, users were manually tracking and deploying updates.
3. Custom VM images often leads to compliance scrutiny, causing delays in the assessment, and implementation process.
4. To automate at-scale, user couldn’t set up VM images and VMs from Azure. This required switching to on-premises tools.

# Example scenario
Suppose you're responsible for deploying and configuring the VMs on Azure Stack HCI cluster to support an internal testing team. 

Multiple such internal teams ask for new virtual machines regularly, so the deployment process has become time-consuming. You want to find a way to automate the process so that you can focus on other key tasks.

You also want your colleagues to be able to make changes and deploy the VMs themselves. But you need to make sure your colleagues follow the same process that you use!

# Solution
You decide to create a deployment workflow that will run automatically every time the Bicep code is updated in your shared repository. The workflow will deploy your Bicep files to Azure.
1. Author Azure Bicep file to create VM images and VMs
2. Set up GitHub Actions to run automatically when Bicep code is updated
3. Configure Actions to deploy VM images and VMs from Azure.

# Steps

## Prerequisites
To work through the sample, you'll need an Azure account, with the ability to create resource groups, Azure Active Directory applications and access to Azure Stack HCI clusters with [Arc VM management configured](https://aka.ms/arcenabledhci).

You'll also need the following installed locally:
- [Visual Studio Code](https://code.visualstudio.com/)
- The [Bicep extension for VS Code](https://marketplace.visualstudio.com/items?itemName=ms-azuretools.vscode-bicep).
- The [GitHub Pull Requests and Issues extension for VS Code](https://marketplace.visualstudio.com/items?itemName=GitHub.vscode-pull-request-github)
- [Git](https://git-scm.com/download)

## Create and clone the GitHub repository in VS Code
1. In a browser, go to [GitHub](www.github.com). Sign in by using your GitHub account, or create a new account if you don't have one.
2. Create [a new repository](https://github.com/new) on your personal account or any organization. Refer [Create a new repository](https://docs.github.com/repositories/creating-and-managing-repositories/creating-a-new-repository).
3. In Visual Studio Code, clone your repository. Refer [Working with GitHub in VS Code
](https://code.visualstudio.com/docs/sourcecontrol/github).

## Create a workflow identity
> NOTE
> To successfully run the below script to set up you need to appropriate permissions. If not, ask this script to be executed by  your administrator.
>    - Ensure that you've permissions to create Azure AD Application
>    - Assign the AAD application "Contributor" permissions to the resource group where VMs and VM images will be created. You must have access to the `Microsoft.Authorization/roleAssignments/write` action. Of the built-in roles, only [User Access Administrator](https://learn.microsoft.com/azure/role-based-access-control/built-in-roles#user-access-administrator) and [Owner](https://learn.microsoft.com/azure/role-based-access-control/built-in-roles#owner) and are granted access to this action.

1. Download the files `workflow-identity-setup.sh` and `aad-fed-cred.json`:
    1. To setup identity, download script, [../cli-common/workflow-identity-setup.sh](https://raw.githubusercontent.com/anoobbacker/ashci-automation-samples/main/cli-common/workflow-identity-setup.sh)
    2. To set up AAD Federation Credentials, download JSON [../json/aad-fed-cred.json](https://raw.githubusercontent.com/anoobbacker/ashci-automation-samples/main/json/aad-fed-cred.json). `workflow-identity-setup.sh` script uses this JSON.
2. Change the variables in `workflow-identity-setup.sh`
    ```bash
    # Assigning default values for variable
    subscription=${1:-"00000000-0000-0000-0000-000000000000"} # Replace with your Subscription ID
    resourcegroup=${2:-"HCICluster"} # Replace with your resource group where the bicep file will be deployed
    githubOrganizationName=${3:-"anoobbacker"} # Replace mygithubuser with your GitHub username
    githubRepositoryName=${4:-"ashci-automation-samples"} # Replace with your GitHub repository
    aadFedCredFile=${5:-"./aad-fed-cred.json"} # Replace with the path to your AAD Fed Cred JSON file
    ```
3. Launch Cloud Shell from the the top navigation of the Azure Portal. Refer [Quickstart for Azure Cloud Shell](https://learn.microsoft.com/azure/cloud-shell/quickstart?tabs=azurecli)
4. Upload files `workflow-identity-setup.sh` and `aad-fed-cred.json` into Cloud Shell. Refer [Upload files](https://learn.microsoft.com/azure/cloud-shell/using-the-shell-window#upload-and-download-files)
5. In Azure Cloud Shell, change the permission to execute the file.
    ```bash
    chmod +x workflow-identity-setup.sh
    ```
6. Execute the script `workflow-identity-setup.sh` to show you the value you need to create as GitHub secrets.
    ```bash
    ...
    AZURE_CLIENT_ID: xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
    AZURE_TENANT_ID: xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
    AZURE_SUBSCRIPTION_ID: xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
    ```
## Create GitHub secrets
1. In your browser, navigate to your GitHub repository.
2. Select **Settings** > **Secrets and variables** > **Actions**.
3. Select **New repository secret**.
4. Name the secret *AZURE_CLIENT_ID*.
5. In the **Value** field, paste the GUID from the first line of the terminal output. Don't include *AZURE_CLIENT_ID*, the colon, or any spaces in the value.
6. Click **Add secret**.
7. Repeat the process to create the secrets for *AZURE_TENANT_ID* and *AZURE_SUBSCRIPTION_ID*, copying the values from the corresponding fields in the terminal output.
8. Repeat the process to create the secret for *VMADMIN_DEFAULT_PASSWORD*. The value here would be the default password for your virtual machines.
8. Verify that all four secrets *AZURE_CLIENT_ID*, *AZURE_TENANT_ID*,  *AZURE_SUBSCRIPTION_ID* and *VMADMIN_DEFAULT_PASSWORD* shows in your list of secrets now.

## Create Bicep file
1. To download the Azure Marketplace VM images, create `bicep/vmimage-create.bicep`.
2. Save your changes to the file. Your file should look like this example:
    ```bicep
    @description('The Azure region into which the resources should be deployed.')
    param region string = resourceGroup().location

    var imagesList = [
    {
        imageName: 'anoob-bicep-vmimage01' //Replace with your image name
        osType: 'Windows' //Replace with your image OS type
        publisherId: 'microsoftwindowsserver' //Replace with your image publisher ID
        offerId: 'windowsserver' // Replace with your image offer ID
        planId: '2022-datacenter-azure-edition-core' //Replace with your image plan ID
        skuVersion: '20348.1129.221104' //Replace with your image SKU version
        generation: 'V2' //Replace with your image generation
        customLocation: '/subscriptions/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx/resourcegroups/RESOURCE-GROUP-PLACEHOLDER/providers/microsoft.extendedlocation/customlocations/CUSTOMLOCATION-NAME-PLACEHOLDER' //Replace with your custom location ID
        region: region
    }
    {
        imageName: 'anoob-bicep-vmimage02' //Replace with your image name
        osType: 'Windows'//Replace with your image OS type
        publisherId: 'microsoftwindowsserver' //Replace with your image publisher ID
        offerId: 'windowsserver' // Replace with your image offer ID
        planId: '2022-datacenter-azure-edition' //Replace with your image plan ID
        skuVersion: '20348.768.220609' //Replace with your image SKU version
        generation: 'V2' //Replace with your image generation
        customLocation: '/subscriptions/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx/resourcegroups/RESOURCE-GROUP-PLACEHOLDER/providers/microsoft.extendedlocation/customlocations/CUSTOMLOCATION-NAME-PLACEHOLDER' //Replace with your custom location ID
        region: region
    }
    ]

    resource vmimages 'microsoft.azurestackhci/marketplacegalleryimages@2021-09-01-preview' = [ for image in imagesList: {
    name: image.imageName
    location: image.region
    extendedLocation: {
        name: image.customLocation
        type: 'CustomLocation'
    }
    tags: {
    }
    properties: {
        osType: image.osType
        resourceName: image.imageName
        hyperVGeneration: image.generation
        identifier: {
        publisher: image.publisherId
        offer: image.offerId
        sku: image.planId
        }
        version: {
        name: image.skuVersion
        }
    }
    }]
    ```
3. To create Arc VMs on Azure Stack HCI using Azure Marketplace VM images, create `bicep/vm-create.bicep`.
4.  Save your changes to the file. Your file should look like this example:
    ```bicep
    @description('The Azure region into which the resources should be deployed.')
    param region string = resourceGroup().location

    @description('The virtual machine admin username.')
    @minLength(5)
    param adminUsername string = 'anoobbacker' //Replace with your admin user name

    @description('The virtual machine admin password.')
    @minLength(9)
    @secure()
    param adminPassword string

    @description('Array of VM configuration objects. This array is looped to create VMs')
    var vmList = [
    {
        name: 'anbacker-bicep-vm01' //Replace with your VM name
        location: region
        customLocation: '/subscriptions/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx/resourcegroups/RESOURCE-GROUP-PLACEHOLDER/providers/microsoft.extendedlocation/customlocations/CUSTOMLOCATION-NAME-PLACEHOLDER' //Replace with your custom location ID
        hardwareProfile: {processors: 4, memoryGB: 8 } //Replace with your hardware profile
        osType: 'Windows' //Replace with your OS type
        adminUserName: adminUsername
        adminPasswd: adminPassword
        image: '/subscriptions/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx/resourceGroups/RESOURCE-GROUP-PLACEHOLDER/providers/Microsoft.AzureStackHCI/marketplaceGalleryImages/VMIMAGE-NAME-PLACEHOLDER' //Replace with your VM image
    }
    ]

    resource vms 'Microsoft.AzureStackHCI/virtualmachines@2021-09-01-preview' = [ for vm in vmList: {
    name: vm.name
    location: vm.location
    properties: {
        resourceName: vm.name
        hardwareProfile: vm.hardwareProfile
        osProfile: {
        adminUsername: vm.adminUserName
        adminPassword: vm.adminPasswd
        osType: vm.osType
        computerName: take(uniqueString(vm.name),15) //Refer https://learn.microsoft.com/en-us/windows-hardware/customize/desktop/unattend/microsoft-windows-shell-setup-computername
        }
        storageProfile: {
        imageReference: {
            name: vm.image
        }
        }
    }
    extendedLocation: {
        type: 'CustomLocation'
        name: vm.customLocation
    }
    }]
    ```
## Create workflow steps
1. Create `.github/workflows/vmimage-workflow.yml`
2. Save your changes to the file. Your file should look like this example:
    ```yaml
    name: deploy-vmimages

    on: [workflow_dispatch]

    permissions:
    id-token: write
    contents: read

    jobs:
    deploy:
        runs-on: ubuntu-latest
        steps:
        - uses: actions/checkout@v3
        - uses: azure/login@v1
        with:
            client-id: ${{ secrets.AZURE_CLIENT_ID }}
            tenant-id: ${{ secrets.AZURE_TENANT_ID }}
            subscription-id: ${{ secrets.AZURE_SUBSCRIPTION_ID }}
        - uses: azure/arm-deploy@v1
        with:
            deploymentName: ${{ github.run_number }}
            resourceGroupName: ${{ env.AZURE_RESOURCEGROUP_NAME }}
            template: ./bicep/vmimage-create.bicep

    ```
3. Create `.github/workflows/vm-workflow.yml`
4. Save your changes to the file. Your file should look like this example:
    ```yaml
    name: deploy-vms

    on: [workflow_dispatch]

    permissions:
    id-token: write
    contents: read

    jobs:
    deploy:
        runs-on: ubuntu-latest
        steps:
        - uses: actions/checkout@v3
        - uses: azure/login@v1
        with:
            client-id: ${{ secrets.AZURE_CLIENT_ID }}
            tenant-id: ${{ secrets.AZURE_TENANT_ID }}
            subscription-id: ${{ secrets.AZURE_SUBSCRIPTION_ID }}
        - uses: azure/arm-deploy@v1
        with:
            deploymentName: ${{ github.run_number }}
            resourceGroupName: ${{ env.AZURE_RESOURCEGROUP_NAME }}
            template: ./bicep/vm-create.bicep
    ```
5. In the Visual Studio Code terminal, stage your changes, commit them to your repository, and push them to Azure Repos:
    ```bash
    git add .
    git commit -m 'Add Azure Bicep and GitHub Action Workflows'
    git push
    ```

## Run your workflow for downloading VM images
1. In your browser, open the workflow by selecting Actions > deploy-vmimages.
2. Select Run workflow > Run workflow.
3. A new run of your workflow will appear in the runs list. If it doesn't appear, refresh your browser page.
4. Select the running workflow to view the details of the run.
5. Inspect the rest of your workflow output.

The workflow shows a successful deployment.

## Run your workflow for creating the VMs
1. In your browser, open the workflow by selecting Actions > deploy-vms.
2. Select Run workflow > Run workflow.
3. A new run of your workflow will appear in the runs list. If it doesn't appear, refresh your browser page.
4. Select the running workflow to view the details of the run.
5. Inspect the rest of your workflow output.

The workflow shows a successful deployment.


## Verify the deployment
1. Go to the [Azure portal](https://portal.azure.com)
2. Search for the resource group where the bicep template was deployed.
3. Click Deployments menu to see the details of the deployment.
4. To see which resources were deployed, select the deployment. To expand the deployment and see more details, select Deployment details. 

In this case, there's two VM images and a VM created using that VM image.

## Update the workflow you created to run automatically 
A collegue asks you to enable creation of the VMs so that they can follow the same steps whenever similar VM creation requests come. You'll update the VM creation workflow to run automatically whenever a the Bicep file changes on your main branch.
1. In Visual Studio Code, open the .github/workflows/vm-workflow.yml file.
2. At the top of the file, after the line `name: deploy-vms`, remove remove the manual trigger, which is the line that currently reads `on: [workflow_dispatch]` and add the following code to prevent multiple simultaneous workflows runs:
    ```diff
    - on: [workflow_dispatch]
    + on:
    +  push:
    +    branches:
    +      - main
    +    paths:
    +      - 'bicep/vm-create.bicep'
    +
    ```
3. In the Visual Studio Code terminal, commit your changes and push them:
    ```bash
    git add .
    git commit -m 'Enable automatically trigerring Bicep deployment on file change merge in main branch'
    git push
    ```

