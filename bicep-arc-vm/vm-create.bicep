@description('The Azure region into which the resources should be deployed.')
param region string = resourceGroup().location

@description('The virtual machine admin username.')
@minLength(5)
param adminUsername string = 'adminuser'

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
