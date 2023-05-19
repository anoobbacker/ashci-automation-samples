#!/usr/bin/env bash

# Exit immediately if a command exits with a non-zero status
set -e

# Treat unset variables as an error when substituting
set -u

# Consider failure of any part of a pipe as a whole pipe failure
set -o pipefail

# Log file
logfile="./output.log"

# Function to show command info
show_command_info() {
    echo "$1" | tee -a $logfile
}

# Assigning subscription and resource group
subscription=${1:-"00000000-0000-0000-0000-000000000000"}
resourcegroup=${2:-"HCICluster"}
clusterName=${3:-"HCICluster"}
arcSettingName=${4:-"default"}
extensionName=${5:-"AdminCenter"}
extensionType=${6:-"AdminCenter"}
portNumber=${7:-'{ "port": "6516" }}'}
extensionPublisher=${8:-"Microsoft.AdminCenter"}

show_command_info "Assigning subscription ${subscription}"
show_command_info "Assigning resourcegroup ${resourcegroup}"
show_command_info "Assigning clusterName ${clusterName}"
show_command_info "Assigning arcSettingName ${arcSettingName}"
show_command_info "Assigning extensionName ${extensionName}"
show_command_info "Assigning extensionPort ${portNumber}"
show_command_info "Assigning extensionPublisher ${extensionPublisher}"
show_command_info "Assigning extensionType ${extensionType}"

# Ensure that the Azure CLI is logged in and set to the correct subscription
show_command_info "Ensuring that the Azure CLI is logged in and set to the correct subscription"
if az account show --output none; then
    show_command_info "Setting subscription to ${subscription}"
    az account set --subscription "${subscription}" || { echo "Failed to set subscription. Exiting." | tee -a $logfile; exit 1; }
else
    show_command_info "Azure CLI not logged in. Please log in and try again."
    exit 1
fi

show_command_info "Checking if extension ${extensionName} exists"
extn_ids=$(az stack-hci extension list \
    --arc-setting-name "${arcSettingName}" \
    --cluster-name "${clusterName}" \
    --resource-group "${resourcegroup}"  \
    --query "[?name=='${extensionName}'].{Name:name, ManagedBy:managedBy, ProvisionStatus:provisioningState, State: aggregateState, Type:extensionParameters.type}"  \
    -o table) || { echo "Failed to get extension list. Exiting."| tee -a $logfile; exit 1; }

if [ -z "$extn_ids" ]
then
      show_command_info "No extension found with name ${extensionName}"
      
      show_command_info "Enabling arc-setting with name ${arcSettingName}"
      az stack-hci arc-setting update \
        --resource-group "${resourcegroup}" \
        --cluster-name "${clusterName}" \
        --name "${arcSettingName}" \
        --connectivity-properties '{"enabled": true}' | tee -a $logfile || { show_command_info "Failed to update arc-setting. Exiting."; exit 1; }
    

      show_command_info "Creating extension with name ${extensionName}"
      az stack-hci extension create \
        --arc-setting-name "${arcSettingName}" \
        --cluster-name "${clusterName}" \
        --resource-group "${resourcegroup}" \
        --name "${extensionName}" \
        --settings "${portNumber}" \
        --type "${extensionType}" || { show_command_info "Failed to create extension. Exiting."; exit 1; }

    show_command_info "Extension ${extensionName} created successfully"
fi