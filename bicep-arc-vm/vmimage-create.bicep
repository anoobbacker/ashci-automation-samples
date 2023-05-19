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
