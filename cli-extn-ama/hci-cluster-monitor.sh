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
clusterName=${4:-"HCICluster"} # Replace with your cluster name
dcrName=${5:-"hcicluster-dcr-rule"} # Replace with your DCR name
dcrFile=${6:-"dcr.json"} # Replace with your DCR file
dcrWorkSpace=${7:-"hcicluster-la-workspace01"} # Replace with your Log Analytics workspace name
dcrAssociationName=${8:-"hcicluster-dcr-association"} # Replace with your DCR association name
dceName=${9:-"hcicluster-dce"} # Replace with your DCE Name
alertRuleName=${10:-"hcicluster-alert"} # Replace with your Log Alert Rule Name
alertActionGroupName=${11:-"hcicluster-actiongrp"} # Replace with your Alert Action Group
alertAdminEmail=${12:-"email@domain.com"} # Replace with your admin email.
alertCPUThreshold=${12:-1} # Replace with your CPU Threshold, setting a low value to validate email getting generated

# Assign variables
extensionName="AzureMonitorWindowsAgent"
arcSettingName="default"
extensionType="AzureMonitorWindowsAgent"
extensionPublisher="Microsoft.Azure.Monitor"
dcrId="e-893e-96cf53985a57"
clusterResourceId="/subscriptions/${subscription}/resourceGroups/${resourceGroup}/providers/Microsoft.AzureStackHCI/clusters/${clusterName}"
dcrRuleId="/subscriptions/${subscription}/resourceGroups/${resourceGroup}/providers/Microsoft.Insights/dataCollectionRules/${dcrName}"
dcrTempFile="dcr-temp.json"

echo "Values assigned for: subscription ${subscription}"
echo "Values assigned for: resourceGroup ${resourceGroup}"
echo "Values assigned for: clusterName ${clusterName}"
echo "Values assigned for: arcSettingName ${arcSettingName}"
echo "Values assigned for: extensionName ${extensionName}"
echo "Values assigned for: extensionPublisher ${extensionPublisher}"
echo "Values assigned for: extensionType ${extensionType}"
echo "Values assigned for: dcrName ${dcrName}"
echo "Values assigned for: dcrFile ${dcrFile}"
echo "Values assigned for: dcrWorkSpace ${dcrWorkSpace}"
echo "Values assigned for: dcrId ${dcrId}"
echo "Values assigned for: dcrAssociationName ${dcrAssociationName}"
echo "Values assigned for: clusterResourceId ${clusterResourceId}"
echo "Values assigned for: dcrRuleId ${dcrRuleId}"
echo "Values assigned for: dcrTempFile ${dcrTempFile}"
echo "Values assigned for: dceName ${dceName}"
echo "Values assigned for: alertRuleName ${alertRuleName}"
echo "Values assigned for: alertActionGroupName ${alertActionGroupName}"
echo "Values assigned for: alertAdminEmail ${alertAdminEmail}"
echo "Values assigned for: alertCPUThreshold ${alertCPUThreshold}"
echo ""

# Ensure that the Azure CLI is logged in and set to the correct subscription
echo "Ensuring that the Azure CLI is logged in and set to the correct subscription" | tee -a $logfile
if az account show --output none; then
    echo "Setting subscription to ${subscription}" | tee -a $logfile
    echo ""
    az account set --subscription "${subscription}" || { echo "Failed to set subscription. Exiting." | tee -a $logfile; exit 1; }
else
    echo "Azure CLI not logged in. Please log in and try again." | tee -a $logfile
    exit 1
fi

# Querying the list of extensions for the specified cluster
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

echo ""
echo "Checking if DCE ${dceName} exists" | tee -a $logfile
dceIds=$(az monitor data-collection endpoint list --resource-group "${resourceGroup}" --query "[?name=='${dceName}'].[id]" --output tsv || { echo "Failed to list DCE. Exiting." | tee -a $logfile; exit 1; })
if [ -z "${dceIds}" ]
then
    echo "No DCE found with name ${dceName}" | tee -a $logfile

    echo "Creating DCE ${dceName}" | tee -a $logfile
    az monitor data-collection endpoint create --resource-group "${resourceGroup}" --location "${region}" --name "${dceName}" --public-network-access "Enabled" || { echo "Failed to DCE. Exiting." | tee -a $logfile; exit 1; }
else
    echo "DCE with name ${dceName} already exits. Skipping DCE creation!" | tee -a $logfile
fi

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
    sed  -i "s/RESOURCEGROUP-PLACEHOLDER/${resourceGroup}/g" "${dcrTempFile}" || { echo "Failed to replace RESOURCEGROUP-PLACEHOLDER in DCR file. Exiting." | tee -a $logfile;}
    sed  -i "s/DCR-NAME-PLACEHOLDER/${dcrWorkSpace}/g" "${dcrTempFile}" || { echo "Failed to replace DCR-NAME-PLACEHOLDER in DCR file. Exiting." | tee -a $logfile;}
    sed  -i "s/DCR-ID-PLACEHOLDER/${dcrId}/g" "${dcrTempFile}" || { echo "Failed to replace DCR-ID-PLACEHOLDER in DCR file. Exiting." | tee -a $logfile;}
    sed  -i "s/DCE-NAME-PLACEHOLDER/${dceName}/g" "${dcrTempFile}" || { echo "Failed to replace DCE-NAME-PLACEHOLDER in DCR file. Exiting." | tee -a $logfile;}    

    echo "Creating DCR ${dcrName} using ${dcrTempFile}"  | tee -a $logfile
    az monitor data-collection rule create --name "${dcrName}" --resource-group "${resourceGroup}" --rule-file "${dcrTempFile}" --description "Automation Demo DCR created" --location "${region}" || { echo "Failed to create extension. Exiting." | tee -a $logfile; exit 1; }
    
else
    echo "DCR with name ${dcrName} already exits. Skipping DCR creation!" | tee -a $logfile
fi

echo ""
echo "Checking if DCR association ${dcrAssociationName} exists" | tee -a $logfile
dcrRuleAssocIds=$(az monitor data-collection rule association list --resource-group "${resourceGroup}" --rule-name "${dcrName}" --query "[?name=='${dcrAssociationName}'].[id]" --output tsv || { echo "Failed to list DCR Association. Exiting." | tee -a $logfile; exit 1; })
if [ -z "${dcrRuleAssocIds}" ]
then
    echo "Create DCR association for ${dcrRuleId} ==> ${clusterResourceId}" | tee -a $logfile
    az monitor data-collection rule association create --name "${dcrAssociationName}" --resource "${clusterResourceId}" --rule-id "${dcrRuleId}" || { echo "Failed to create DCR Association. Exiting." | tee -a $logfile; exit 1; }
else
    echo "DCR association with name ${dcrAssociationName} already exits. Skipping DCR association creation!" | tee -a $logfile
fi

echo ""
echo "Checking if Action Group ${alertActionGroupName} exists" | tee -a $logfile
alertActionGrpIds=$(az monitor action-group list --resource-group "${resourceGroup}" --query "[?name=='${alertActionGroupName}'].[id]" --output tsv || { echo "Failed to list Action Group. Exiting." | tee -a $logfile; exit 1; })
if [ -z "${alertActionGrpIds}" ]
then
    echo "Create Action Group for ${alertActionGroupName}" | tee -a $logfile
    az monitor action-group create --name ${alertActionGroupName} --resource-group "${resourceGroup}" --location "${region}" --action "email hcicluster-action ${adminEmail}" || { echo "Failed to create extension. Exiting." | tee -a $logfile; exit 1; }

    alertActionGrpIds=$(az monitor action-group list --resource-group "${resourceGroup}" --query "[?name=='${alertActionGroupName}'].[id]" --output tsv || { echo "Failed to list Action Group. Exiting." | tee -a $logfile; exit 1; })
else
    echo "Action Group with name ${alertActionGroupName} already exits. Skipping Action Group creation!" | tee -a $logfile
fi

echo ""
echo "Checking if Log Alert Rule ${alertRuleName} exists" | tee -a $logfile
alertRuleIds=$(az monitor scheduled-query list --resource-group "${resourceGroup}" --query "[?name=='${alertRuleName}'].[id]" --output tsv || { echo "Failed to list Log Alert Rule. Exiting." | tee -a $logfile; exit 1; })
if [ -z "${alertRuleIds}" ]
then
    echo "Create Log Alert Rule for ${alertRuleName}" | tee -a $logfile

    az monitor scheduled-query create --resource-group "${resourceGroup}" -n "${alertRuleName}" --scopes "${clusterResourceId}" --location "${region}" --action-groups "${alertActionGrpIds}" --evaluation-frequency "1h" --severity "" --condition "Event | where EventLog =~ ;'Microsoft-Windows-SDDC-Management/Operational' and EventID == '3000' | extend ClusterData = parse_xml(EventData) | extend ClusterName = tostring(ClusterData.DataItem.UserData.EventData['ClusterName']) | extend ClusterArmId = tostring(ClusterData.DataItem.UserData.EventData['ArmId']) | where ClusterArmId =~ '${clusterResourceId}' | summarize arg_max(TimeGenerated, RenderedDescription) | extend servers_information = parse_json(RenderedDescription).m_servers | mv-expand servers_information | extend Nodename = tostring(servers_information.m_name) | extend UsedCpuPercentage = toint(servers_information.m_totalProcessorsUsedPercentage)| where UsedCpuPercentage >= ${alertCPUThreshold}" --description "Alert rule created via automation!"  || { echo "Failed to create Log Alert Rule. Exiting." | tee -a $logfile; exit 1; }
else
    echo "Log Alert Rule with name ${dcrAssociationName} already exits. Skipping DCR association creation!" | tee -a $logfile
fi
