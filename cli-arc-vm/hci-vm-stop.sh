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
resourcegroup=${2:-"hcicluster-rg"} # Replace with your resource group name
vmNames=("vmname1" "vmname2" "vmname3") # Replace with your VM names

# Counters for report
total_vms=${#vmNames[@]}
successful_shutdowns=0
skipped_vms=0

# Ensure that the Azure CLI is logged in and set to the correct subscription
echo "Ensuring that the Azure CLI is logged in and set to the correct subscription" | tee -a $logfile
if az account show --output none; then
    echo "Setting subscription to ${subscription}" | tee -a $logfile
    az account set --subscription "${subscription}" || { echo "Failed to set subscription. Exiting." | tee -a $logfile; exit 1; }
else
    echo "Azure CLI not logged in. Please log in and try again." | tee -a $logfile
    exit 1
fi

# Iterate over VMs
for vm in "${vmNames[@]}"; do
    # Check if VM name is null or empty
    if [ -z "$vm" ]; then
        echo "Skipping VM because its name is null or empty."
        skipped_vms=$((skipped_vms+1))
        continue
    fi

    # Querying the list of extensions for the specified cluster
    echo "Checking if VM ${vm} exists" | tee -a $logfile
    vmIds=$(az azurestackhci virtualmachine list --resource-group ${resourcegroup} --query "[?name=='${vm}'].id" --output tsv) || { echo "Failed to get VM list. Exiting."| tee -a $logfile; exit 1; }
    if [ -z "$vmIds" ]
    then
        echo "Skipping VM ${vm} because it does not exist" | tee -a $logfile
        skipped_vms=$((skipped_vms+1))
        continue
    fi

    echo "VM ${vm} exists" | tee -a $logfile

    echo "Stopping VM ${vm}" | tee -a $logfile
    az azurestackhci virtualmachine stop --name "${vm}" --resource-group "${resourcegroup}"|| { echo "Failed to stop VM ${vm}. Exiting."| tee -a $logfile; exit 1; }
    if [ $? -eq 0 ]; then
        echo "Successfully shut down VM '$vm'."
        successful_shutdowns=$((successful_shutdowns+1))
    else
        echo "Failed to shut down VM '$vm'."
        skipped_vms=$((skipped_vms+1))
    fi
done

# Print report
echo "---------------------------------------------------"
echo "Total VMs: $total_vms"
echo "Successfully shut down: $successful_shutdowns"
echo "Skipped: $skipped_vms"