# Azure CLI Automation: Start and Stop Arc VMs on Azure Stack HCI
In this sample, you'll learn how to start and stop Arc VMs on Azure Stack HCI using Azure CLI.

Short URL to this page: [https://aka.ms/ashci/automate-cli/arc-vm](https://aka.ms/ashci/automate-cli/arc-vm)

# Problem
- Performing multiple tasks on many HCI clusters through Azure Portal become an effort intensive and time-consuming process, especially when these tasks needs to be frequently repeated.
- Organization’s skilled administrators prefer Linux based Bash scripting to automate tasks from Azure. Otherwise, they require training in ARM templates or Azure PowerShell, this need time and delays deployment.


# Example scenario
Suppose you’re responsible for setting up and managing VMs on Azure Stack HCI cluster to support your internal teams.

One day, the billing team asks you to start a VM at 6PM and shutdown by 9PM. However, the HCI clusters are nearly full capacity. 

Through internal discussions, you learn that some teams do not use the VMs from 5PM to 9AM. So, your idea is to shutdown those idle VMs to fulfill the billing team’s requirement.

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

Install the below Azure CLI extensions:
- To set up Arc-VM Management Client on Azure Stack HCI, run the command `az extension add --name stackhci`

## Create scripts to start and stop VMs
1. To manage virtual machines, open Visual Studio Code Explorer and at the root of your project folder, create `hci-vm-start.sh` and `hci-vm-stop.sh`.
2. To stop the virtual machines, save your changes to the file `hci-vm-stop.sh`. Your file should look like this example:
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
    ```
3. To start the virtual machines, save your changes to the file `hci-vm-start.sh`. Your file should look like this example:
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
    resourcegroup=${2:-"hcicluster-rg"} # Replace with your resource group name
    vmNames=("vmname1" "vmname2" "vmname3") # Replace with your VM names

    # Counters for report
    total_vms=${#vmNames[@]}
    successful_started=0
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

        echo "Starting VM ${vm}" | tee -a $logfile
        az azurestackhci virtualmachine start --name "${vm}" --resource-group "${resourcegroup}"|| { echo "Failed to start VM ${vm}. Exiting."| tee -a $logfile; exit 1; }
        if [ $? -eq 0 ]; then
            echo "Successfully started VM '$vm'."
            successful_started=$((successful_started+1))
        else
            echo "Failed to starting VM '$vm'."
            skipped_vms=$((skipped_vms+1))
        fi
    done

    # Print report
    echo "---------------------------------------------------"
    echo "Total VMs: $total_vms"
    echo "Successfully started: $successful_started"
    echo "Skipped: $skipped_vms"
    ```
# Start Azure Cloud Shell instance via VS Code
1. To sign in, go to **View** > **Command Pallete** and type _Azure: Sign In_. There are mulitple commands that may be used to sign in to Azure.
2. Click the dropdown arrow in the terminal view and select _Azure Cloud Shell (Bash)_
3. If this is your first time using the Cloud Shell, the following notification will appear prompting you to set it up.
4. The Cloud Shell will load in the terminal view once you've finished configuring it.

# Upload the file to Azure Cloud Shell
1. To upload `hci-vm-start.sh`, go to **View** > **Command Pallete** and type _Azure: Upload to Cloud Shell_
2. Select the file `hci-vm-start.sh`
3. Repeat the same process to upload `hci-vm-stop.sh`

# Run the script
1. Change the script permission to execute
    ```bash
    chmod +x hci-vm-start.sh hci-vm-stop.sh 
    ```
2. To stop the virtual machines, run the shell script:
    ```bash
    bash hci-vm-stop.sh
    ```
3. To start the virtual machines, run the shell script:
    ```bash
    bash hci-vm-start.sh
    ```
