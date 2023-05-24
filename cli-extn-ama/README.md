# Azure CLI Automation: Enable Azure Monitor HCI Insights on Azure Stack HCI
In this sample, you'll learn how to create Azure Monitor HCI Insights on HCI and confgure Alert rules for Email notification using Azure CLI.

Short URL to this page: [https://aka.ms/ashci/automate-cli/extension-ama](https://aka.ms/ashci/automate-cli/extension-ama)

# Problem
- Performing multiple tasks on many HCI clusters through Azure Portal become an effort intensive and time-consuming process, especially when these tasks needs to be frequently repeated.

- Organization’s skilled administrators prefer Linux based Bash scripting to automate tasks from Azure. Otherwise, they require training in ARM templates or Azure PowerShell, this need time and delays deployment.

# Example scenario
Suppose you’re responsible for managing Azure Stack HCI clusters deployed across various Edge locations from Azure.

To guarantee a reliable user experience, it is crucial to minimize downtime.

You got to learn that Azure Stack HCI clusters support monitoring features and can be set up from Azure.

You want to find a way to automate this process.

# Solution
1. Author Azure CLI script. Azure CLI syntax is like Bash scripting
2. Use Azure Cloud Shell’s Bash environment.
3. Run Azure CLI script to automate the tasks.

![image](https://github.com/anoobbacker/ashci-automation-samples/assets/13219906/e0c62aac-5f83-464c-9d6d-216a34c0fea1)

# Steps

## Prerequisites
To work through the sample, you'll need an Azure account, and [insights prerequisites configured](https://learn.microsoft.com/azure-stack/hci/manage/monitor-hci-single?tabs=22h2#prerequisites-for-enabling-insights).

You'll also need the following installed locally:
- [Visual Studio Code](https://code.visualstudio.com/)
- The [Azure Account extension for VS Code](https://marketplace.visualstudio.com/items?itemName=ms-vscode.azure-account).
- On Windows: Requires Node.js 6 or later to be installed (https://nodejs.org).

## Create DCR JSON
1. To set up Azure Monitor Insights, open Visual Studio Code Explorer and at the root of your project folder, create `dcr.json`.
2. Save your changes to the file. Your file should look like this example:
    ```json
    {
        "properties": {
        "dataCollectionEndpointId": "/subscriptions/SUBSCRIPTION-PLACEHOLDER/resourceGroups/RESOURCEGROUP-PLACEHOLDER/providers/Microsoft.Insights/dataCollectionEndpoints/DCE-NAME-PLACEHOLDER",
        "destinations": {
            "logAnalytics": [
            {
                "workspaceResourceId": "/subscriptions/SUBSCRIPTION-PLACEHOLDER/resourceGroups/RESOURCEGROUP-PLACEHOLDER/providers/Microsoft.OperationalInsights/workspaces/WORKSPACENAME-PLACEHOLDER",
                "name": "DCR-NAME-PLACEHOLDER"
            },
            {
                "workspaceResourceId": "/subscriptions/SUBSCRIPTION-PLACEHOLDER/resourceGroups/RESOURCEGROUP-PLACEHOLDER/providers/Microsoft.OperationalInsights/workspaces/WORKSPACENAME-PLACEHOLDER",
                "name": "DCR-ID-PLACEHOLDER"
            }
            ]
        },
        "dataSources": {
            "performanceCounters": [
            {
                "name": "perfCounterDataSource",
                "samplingFrequencyInSeconds": 10,
                "streams": [
                "Microsoft-Perf"
                ],
                "counterSpecifiers": [
                "\\Memory\\Available Bytes",
                "\\Network Interface(*)\\Bytes Total/sec",
                "\\Processor(_Total)\\% Processor Time",
                "\\RDMA Activity(*)\\RDMA Inbound Bytes/sec",
                "\\RDMA Activity(*)\\RDMA Outbound Bytes/sec"
                ]
            }
            ],
            "windowsEventLogs": [
            {
                "name": "eventLogsDataSource",
                "streams": [
                "Microsoft-Event"
                ],
                "xPathQueries": [
                "Microsoft-Windows-FailoverClustering/Diagnostic!*",
                "Microsoft-Windows-SDDC-Management/Operational!*[System[(EventID=3000 or EventID=3001 or EventID=3002 or EventID=3003 or EventID=3004)]]",
                "microsoft-windows-health/operational!*"
                ]
            }
            ]
        },
        "dataFlows": [
            {
            "streams": [
                "Microsoft-Perf"
            ],
            "destinations": [
                "DCR-ID-PLACEHOLDER"
            ]
            },
            {
            "streams": [
                "Microsoft-Event"
            ],
            "destinations": [
                "DCR-ID-PLACEHOLDER"
            ]
            }
        ]
        }
    }    
    ```

## Create the script
1. Create the file `hci-cluster-monitor.sh` and save your changes to the file. Your file should look like this example:
    ```bash
    #!/bin/bash

    # Exit immediately if a command exits with a non-zero status
    set -e

    # Treat unset variables as an error when substituting
    set -u

    # Consider failure of any part of a pipe as a whole pipe failure
    set -o pipefail

    # Log file
    logfile="./output.log"

    # Assigning default values for variable
    subscription=${1:-"00000000-0000-0000-0000-000000000000"} # Replace with your subscription ID
    resourceGroup=${2:-"hcicluster-rg"} # Replace with your resource group name
    region=${3:-"eastus"} # Replace with your region
    clusterName=${4:-"hcicluster"} # Replace with your cluster name
    dcrName=${5:-"hcicluster-dcr"} # Replace with your DCR name
    dcrFile=${6:-"dcr.json"} # Replace with your DCR file
    dcrWorkSpaceRg=${7:-"hcicluster-rg"} # Replace with your Log Analytics workspace resoruce group
    dcrWorkSpace=${8:-"hcicluster-la-workspace"} # Replace with your Log Analytics workspace name
    dcrAssociationName=${9:-"hcicluster-dcr-association"} # Replace with your DCR association name
    dceName=${10:-"hcicluster-dce"} # Replace with your DCE Name

    # Assign variables
    extensionName="AzureMonitorWindowsAgent"
    arcSettingName="default"
    extensionType="AzureMonitorWindowsAgent"
    extensionPublisher="Microsoft.Azure.Monitor"
    dcrId="e-893e-96cf53985a57"
    clusterResourceId="/subscriptions/${subscription}/resourceGroups/${resourceGroup}/providers/Microsoft.AzureStackHCI/clusters/${clusterName}"
    dcrRuleId="/subscriptions/${subscription}/resourceGroups/${resourceGroup}/providers/Microsoft.Insights/dataCollectionRules/${dcrName}"
    dcrTempFile="dcr-temp.json"

    echo ""
    echo "Values assigned for: subscription ${subscription}"
    echo "Values assigned for: resourceGroup ${resourceGroup}"
    echo "Values assigned for: clusterName ${clusterName}"
    echo "Values assigned for: arcSettingName ${arcSettingName}"
    echo "Values assigned for: extensionName ${extensionName}"
    echo "Values assigned for: extensionPublisher ${extensionPublisher}"
    echo "Values assigned for: extensionType ${extensionType}"
    echo "Values assigned for: dcrName ${dcrName}"
    echo "Values assigned for: dcrFile ${dcrFile}"
    echo "Values assigned for: dcrWorkSpaceRg ${dcrWorkSpaceRg}"
    echo "Values assigned for: dcrWorkSpace ${dcrWorkSpace}"
    echo "Values assigned for: dcrId ${dcrId}"
    echo "Values assigned for: dcrAssociationName ${dcrAssociationName}"
    echo "Values assigned for: clusterResourceId ${clusterResourceId}"
    echo "Values assigned for: dcrRuleId ${dcrRuleId}"
    echo "Values assigned for: dcrTempFile ${dcrTempFile}"
    echo "Values assigned for: dceName ${dceName}"
    
    
    ```
2. Replace the variables with your environment values like _subscription_, _resourceGroup_, _region_, _clusterName_, _dcrName_, _dcrFile_, _dcrWorkSpaceRg_, _dcrWorkspace_, _dcrAssociationName_ and _dceName_
3. Ensure that subscription is set properly add the below:
    ```bash
    # Ensure that the Azure CLI is logged in and set to the correct subscription
    echo ""
    echo "Ensuring that the Azure CLI is logged in and set to the correct subscription" | tee -a $logfile
    if az account show --output none; then
        echo "Setting subscription to ${subscription}" | tee -a $logfile
        echo ""
        az account set --subscription "${subscription}" || { echo "Failed to set subscription. Exiting." | tee -a $logfile; exit 1; }
    else
        echo "Azure CLI not logged in. Please log in and try again." | tee -a $logfile
        exit 1
    fi
    
    ```
4. To set up the Insights extension add the below:
    ```bash
    # Querying the list of extensions for the specified cluster
    echo ""
    echo "Checking if extension ${extensionName} exists" | tee -a $logfile
    extn_ids=$(az stack-hci extension list \
        --arc-setting-name "${arcSettingName}" \
        --cluster-name "${clusterName}" \
        --resource-group "${resourceGroup}"  \
        --query "[?name=='${extensionName}'].{Name:name, ManagedBy:managedBy, ProvisionStatus:provisioningState, State: aggregateState, Type:extensionParameters.type}"  \
        -o table) || { echo "Failed to get extension list. Exiting."| tee -a $logfile; exit 1; }

    if [ -z "$extn_ids" ]
    then
        echo "No extension found with name ${extensionName}" | tee -a $logfile
        
        echo "Creating extension with name ${extensionName}" | tee -a $logfile
        az stack-hci extension create \
            --arc-setting-name "${arcSettingName}" \
            --cluster-name "${clusterName}" \
            --resource-group "${resourceGroup}" \
            --name "${extensionName}" \
            --auto-upgrade "true" \
            --publisher "${extensionPublisher}" \
            --type "${extensionType}" || { echo "Failed to create extension. Exiting." | tee -a $logfile; exit 1; }
        
    else
        echo "Extension with name ${extensionName} already exits. Skipping extension creation!" | tee -a $logfile
    fi
    
    ```
5. To create Log Analytics Workspace add the below:
```bash
echo ""
echo "Checking if Log Analytics Workspace ${dcrWorkSpace} exists" | tee -a $logfile
wrkSpcIds=$(az monitor log-analytics workspace list --query "[?name=='${dcrWorkSpace}'].[id, name, location]" --output tsv || { echo "Failed to list DCR. Exiting." | tee -a $logfile; exit 1; })
if [ -z "${wrkSpcIds}" ]
then
    echo "No Log Analytics Workspace found with name ${dcrWorkSpace}" | tee -a $logfile

    echo "Creating Log Analytics Workspace ${dcrWorkSpace}" | tee -a $logfile
    az monitor log-analytics workspace create --resource-group "${dcrWorkSpaceRg}" --workspace-name "${dcrWorkSpace}" --location "${region}"|| { echo "Failed to create Log Analytics Workspace. Exiting." | tee -a $logfile; exit 1; }
else
    echo "Log Analytics Workspace with name ${dcrWorkSpace} already exits. Skipping creation!" | tee -a $logfile
fi

```
7. To create Data Collection Endpoint add the below:
    ```bash
    echo ""
    echo "Checking if DCE ${dceName} exists" | tee -a $logfile
    dceIds=$(az monitor data-collection endpoint list --resource-group "${resourceGroup}" --query "[?name=='${dceName}'].[id]" --output tsv || { echo "Failed to list DCE. Exiting." | tee -a $logfile; exit 1; })
    if [ -z "${dceIds}" ]
    then
        echo "No DCE found with name ${dceName}" | tee -a $logfile

        echo "Creating DCE ${dceName}" | tee -a $logfile
        az monitor data-collection endpoint create --resource-group "${resourceGroup}" --location "${region}" --name "${dceName}" --public-network-access "Enabled" || { echo "Failed to DCE. Exiting." | tee -a $logfile; exit 1; }
    else
        echo "DCE with name ${dceName} already exits. Skipping creation!" | tee -a $logfile
    fi
    
    ```

6. To create Data Association Rule (DCR) add the below:
    ```bash
    echo ""
    echo "Checking if DCR ${dcrName} exists" | tee -a $logfile
    dcrRuleIds=$(az monitor data-collection rule list --resource-group "${resourceGroup}" --query "[?name=='${dcrName}'].[id, name, location]" --output tsv || { echo "Failed to list DCR. Exiting." | tee -a $logfile; exit 1; })
    if [ -z "${dcrRuleIds}" ]
    then
        echo "No DCR found with name ${dcrName}" | tee -a $logfile

        echo "Creating temporary DCR file ${dcrTempFile} from ${dcrFile}" | tee -a $logfile
        cp ${dcrFile} ${dcrTempFile} || { echo "Failed to copy ${dcrFile} to ${dcrTempFile}. Exiting." | tee -a $logfile; }

        echo "Replacing placeholders in DCR file ${dcrTempFile}" | tee -a $logfile
        sed -i "s/WORKSPACENAME-PLACEHOLDER/${dcrWorkSpace}/g" "${dcrTempFile}" || { echo "Failed to replace WORKSPACE-RESOURCE-PLACEHOLDER in DCR file. Exiting." | tee -a $logfile; }
        sed  -i "s/SUBSCRIPTION-PLACEHOLDER/${subscription}/g" "${dcrTempFile}" || { echo "Failed to replace SUBSCRIPTION-PLACEHOLDER in DCR file. Exiting." | tee -a $logfile;}
        sed  -i "s/RESOURCEGROUP-PLACEHOLDER/${dcrWorkSpaceRg}/g" "${dcrTempFile}" || { echo "Failed to replace RESOURCEGROUP-PLACEHOLDER in DCR file. Exiting." | tee -a $logfile;}
        sed  -i "s/DCR-NAME-PLACEHOLDER/${dcrWorkSpace}/g" "${dcrTempFile}" || { echo "Failed to replace DCR-NAME-PLACEHOLDER in DCR file. Exiting." | tee -a $logfile;}
        sed  -i "s/DCR-ID-PLACEHOLDER/${dcrId}/g" "${dcrTempFile}" || { echo "Failed to replace DCR-ID-PLACEHOLDER in DCR file. Exiting." | tee -a $logfile;}
        sed  -i "s/DCE-NAME-PLACEHOLDER/${dceName}/g" "${dcrTempFile}" || { echo "Failed to replace DCE-NAME-PLACEHOLDER in DCR file. Exiting." | tee -a $logfile;}    

        echo "Creating DCR ${dcrName} using ${dcrTempFile}"  | tee -a $logfile
        az monitor data-collection rule create --name "${dcrName}" --resource-group "${resourceGroup}" --rule-file "${dcrTempFile}" --description "Automation Demo DCR created" --location "${region}" || { echo "Failed to DCR. Exiting." | tee -a $logfile; exit 1; }
        
    else
        echo "DCR with name ${dcrName} already exits. Skipping creation!" | tee -a $logfile
    fi
    
    ```
7. To create DCR Association, add the below:
    ```bash
    echo ""
    echo "Checking if DCR association ${dcrAssociationName} exists" | tee -a $logfile
    dcrRuleAssocIds=$(az monitor data-collection rule association list --resource-group "${resourceGroup}" --rule-name "${dcrName}" --query "[?name=='${dcrAssociationName}'].[id]" --output tsv || { echo "Failed to list DCR Association. Exiting." | tee -a $logfile; exit 1; })
    if [ -z "${dcrRuleAssocIds}" ]
    then
        echo "Create DCR associating for ${dcrRuleId} ==> ${clusterResourceId}" | tee -a $logfile
        az monitor data-collection rule association create --name "${dcrAssociationName}" --resource "${clusterResourceId}" --rule-id "${dcrRuleId}" || { echo "Failed to create extension. Exiting." | tee -a $logfile; exit 1; }
    else
        echo "DCR association with name ${dcrAssociationName} already exits. Skipping creation!" | tee -a $logfile
    fi
    
    ```
# Start Azure Cloud Shell instance via VS Code
1. To sign in, go to **View** > **Command Pallete** and type _Azure: Sign In_. There are mulitple commands that may be used to sign in to Azure.
2. Click the dropdown arrow in the terminal view and select _Azure Cloud Shell (Bash)_
3. If this is your first time using the Cloud Shell, the following notification will appear prompting you to set it up.
4. The Cloud Shell will load in the terminal view once you've finished configuring it.

# Upload the file to Azure Cloud Shell
1. To upload `dcr.json`, go to **View** > **Command Pallete** and type _Azure: Upload to Cloud Shell_
2. Select the file `dcr.json`
3. Repeat the same process to upload `hci-cluster-monitor.sh`

# Run the script
1. Change the script permission to execute
    ```bash
    chmod +x hci-cluster-monitor.sh
    ```
2. Run the shell script
    ```bash
    bash hci-cluster-monitor.sh
    ```
