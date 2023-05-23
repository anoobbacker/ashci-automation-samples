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
subscription=${1:-"00000000-0000-0000-0000-000000000000"} # Replace with your Subscription ID
resourcegroup=${2:-"HCICluster"} # Replace with your resource group where the bicep file will be deployed
githubOrganizationName=${3:-"anoobbacker"} # Replace mygithubuser with your GitHub username
githubRepositoryName=${4:-"ashci-automation-samples"} # Replace with your GitHub repository
aadFedCredFile=${5:-"./aad-fed-cred.json"} # Replace with the path to your AAD Fed Cred JSON file


# Assigning variables
githubAPIAudience="AzureADTokenExchange"
githubIssuer="token.actions.githubusercontent.com"
aadFedCredDescription="AAD Fed Cred for GitHub Actions"
aadFedCredTempFile=${3:-"./aad-fed-cred-temp.json"}
resourceGrp="/subscriptions/${subscription}/resourceGroups/${resourcegroup}"

if [ ! -f $aadFedCredFile ]; then
    echo "Failed to find the AAD Federation Credential JSON (${aadFedCredFile}). Exiting." | tee -a $logfile; 
    exit 1;
fi

# Ensure that the Azure CLI is logged in and set to the correct subscription
echo "Ensuring that the Azure CLI is logged in and set to the correct subscription" | tee -a $logfile
if az account show --output none; then
    echo "Setting subscription to ${subscription}" | tee -a $logfile
    az account set --subscription "${subscription}" || { echo "Failed to set subscription. Exiting." | tee -a $logfile; exit 1; }
else
    echo "Azure CLI not logged in. Please log in and try again." | tee -a $logfile
    exit 1
fi

# Setup AAD App
echo "Checking if AAD App ${githubRepositoryName} exists" | tee -a $logfile
githubRepoAppId=$(az ad app list --display-name "${githubRepositoryName}" --query "[].[appId]" -o "tsv"|| { echo "Failed to list AAD App. Exiting." | tee -a $logfile; exit 1; })
if [ -z "${githubRepoAppId}" ]
then
    # AAD App does not exist, start creating one.
    echo "AAD App ${githubRepositoryName} does not exist" | tee -a $logfile

    echo "Creating AAD App ${githubRepositoryName}" | tee -a $logfile
    az ad app create --display-name ${githubRepositoryName} || { echo "Failed to create AAD app. Exiting." | tee -a $logfile; exit 1; }

    githubRepoAppId=$(az ad app list --display-name "${githubRepositoryName}" --query "[].[appId]" -o "tsv"|| { echo "Failed to list AAD app. Exiting." | tee -a $logfile; exit 1; })
else
    echo "AAD App ${githubRepositoryName} exists. Skipping create!" | tee -a $logfile
fi

githubObjectId=$(az ad app list --display-name "${githubRepositoryName}" --query "[].[id]" -o "tsv"|| { echo "Failed to list AAD app. Exiting." | tee -a $logfile; exit 1; })
echo "AAD Ids: Object id = ${githubObjectId}, AppId = ${githubRepoAppId}" | tee -a $logfile

# Setup AAD App Credentails  API permissions
echo "Checking if AAD Fed Credentials for ${githubObjectId} exists" | tee -a $logfile
githubFedCredId=$(az ad app federated-credential list --id "${githubObjectId}" --query "[].[id]" -o "tsv"|| { echo "Failed to list AAD Fed Credentials. Exiting." | tee -a $logfile; exit 1; })
if [ -z "${githubFedCredId}" ]
then
    # AAD Fed Cred does not exist, start creating one.
    echo "AAD Fed Credentials for ${githubRepoAppId} does not exist" | tee -a $logfile

    # Create temporary AAD Fed Cred file
    echo "Creating temporary AAD Fed Cred file ${aadFedCredTempFile} from ${aadFedCredFile}" | tee -a $logfile
    cp ${aadFedCredFile} ${aadFedCredTempFile} || { echo "Failed to copy ${aadFedCredFile} to ${aadFedCredTempFile}. Exiting." | tee -a $logfile; }

    # Replace placeholders in AAD Fed Cred file
    echo "Replacing placeholders in AAD Fed Cred file ${aadFedCredTempFile}" | tee -a $logfile
    sed -i "s/AADFEDCRED-NAME-PLACEHOLDER/${githubRepositoryName}/g" "${aadFedCredTempFile}" || { echo "Failed to replace AADFEDCRED-NAME-PLACEHOLDER in AAD Fed Cred file. Exiting." | tee -a $logfile; }
    sed -i "s/AADFEDCRED-DESCRIPTION-PLACEHOLDER/${aadFedCredDescription}/g" "${aadFedCredTempFile}" || { echo "Failed to replace AADFEDCRED-NAME-PLACEHOLDER in AAD Fed Cred file. Exiting." | tee -a $logfile; }
    sed -i "s/AADFEDCRED-AUDIENCE-PLACEHOLDER/${githubAPIAudience}/g" "${aadFedCredTempFile}" || { echo "Failed to replace AADFEDCRED-AUDIENCE-PLACEHOLDER in AAD Fed Cred file. Exiting." | tee -a $logfile; }
    sed -i "s/GIHUB-ISSUER-PLACEHOLDER/${githubIssuer}/g" "${aadFedCredTempFile}" || { echo "Failed to replace GIHUB-ISSUER-PLACEHOLDER in AAD Fed Cred file. Exiting." | tee -a $logfile; }
    sed -i "s/GITHUB-ORG-NAME-PLACEHOLDER/${githubOrganizationName}/g" "${aadFedCredTempFile}" || { echo "Failed to replace GIHUB-SUBJECT-PLACEHOLDER in AAD Fed Cred file. Exiting." | tee -a $logfile; }
    sed -i "s/GITHUB-REPO-NAME-PLACEHOLDER/${githubRepositoryName}/g" "${aadFedCredTempFile}" || { echo "Failed to replace GIHUB-SUBJECT-PLACEHOLDER in AAD Fed Cred file. Exiting." | tee -a $logfile; }

    #create AAD Fed Cred
    az ad app federated-credential create --id "${githubObjectId}" --parameters ${aadFedCredTempFile} || { echo "Failed to create federated-credential. Exiting." | tee -a $logfile; exit 1; }
else
    echo "AAD Fed Credentials for ${githubRepoAppId} exists. Skipping create!" | tee -a $logfile
fi

#create new Azure AD service principal
echo "Checking new Azure AD Service Principal for ${githubObjectId}" | tee -a $logfile
spIds=$(az ad sp list --filter "appId eq '${githubRepoAppId}'" --query "[].[id]" -o "tsv"|| { echo "Failed to list Azure AD Service Principal. Exiting." | tee -a $logfile; exit 1; })
if [ -z "${spIds}" ]
then
    echo "Azure AD Service Principal for ${githubObjectId} does not exist" | tee -a $logfile

    #create new Azure AD service principal
    echo "Creating Azure AD Service Principal for ${githubObjectId}" | tee -a $logfile
    az ad sp create --id "${githubObjectId}" || { echo "Failed to create Azure AD service principal. Exiting." | tee -a $logfile; exit 1; }
else
    echo "Azure AD Service Principal for ${githubObjectId} exists. Skipping create!" | tee -a $logfile
fi

#create new role assignment
echo "Checking new role assignment for ${githubRepoAppId}" | tee -a $logfile
roleAssignmentIds=$(az role assignment list --scope ${resourcegroup} --assignee "${githubRepoAppId}" --query "[].[id]" -o "tsv" || { echo "Failed to list role assignment. Exiting." | tee -a $logfile; exit 1; })
if [ -z "${roleAssignmentIds}" ]
then
    echo "Role assignment for ${githubRepoAppId} does not exist" | tee -a $logfile

    #create new role assignment
    echo "Creating role assignment for ${githubRepoAppId}" | tee -a $logfile
    az role assignment create --assignee "${githubRepoAppId}" --role "Contributor" --scope "${resourcegroup}"|| { echo "Failed to create role assignment. Exiting." | tee -a $logfile; exit 1; }
else
    echo "Role assignment for ${githubRepoAppId} exists. Skipping create!" | tee -a $logfile
fi

# print GitHub secrets
tenantId=$(az account show --query "tenantId" --output tsv || { echo "Failed to list AAD app. Exiting." | tee -a $logfile; exit 1; })

echo "AZURE_CLIENT_ID: ${githubRepoAppId}" | tee -a $logfile
echo "AZURE_TENANT_ID: ${tenantId}" | tee -a $logfile
echo "AZURE_SUBSCRIPTION_ID: ${subscription}" | tee -a $logfile
