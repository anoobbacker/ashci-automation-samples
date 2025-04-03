param customLocationName string
param location string
param imageName string
@allowed([ 'Windows' ])
param osType string = 'Windows'
@allowed([ 
  'microsoftwindowsdesktop:office-365:win11-23h2-avd-m365'
  'microsoftwindowsdesktop:office-365:win11-24h2-avd-m365'
  'microsoftwindowsdesktop:office-365:win10-21h2-avd-m365'
  'microsoftwindowsdesktop:windows-11:win11-23h2-pro'
  'microsoftwindowsdesktop:windows-11:win11-22h2-ent'
  'microsoftwindowsdesktop:windows-11:win11-23h2-ent'
  'microsoftwindowsdesktop:windows-11:win11-24h2-ent'
  'microsoftwindowsdesktop:windows-11:win11-22h2-avd'
  'microsoftwindowsdesktop:windows-11:win11-23h2-avd'
  'microsoftwindowsdesktop:windows-11:win11-24h2-avd'
  'microsoftwindowsdesktop:windows-10:win10-22h2-pro-g2'
  'microsoftwindowsdesktop:windows-10:win10-22h2-ent-g2'
  'microsoftwindowsdesktop:windows-10:win10-22h2-avd'
  'microsoftwindowsserver:windowsserver:2025-datacenter-azure-edition-smalldisk'
  'microsoftwindowsserver:windowsserver:2025-datacenter-azure-edition-core'
  'microsoftwindowsserver:windowsserver:2025-datacenter-azure-edition'
  'microsoftwindowsserver:windowsserver:2022-datacenter-azure-edition-hotpatch'
  'microsoftwindowsserver:windowsserver:2022-datacenter-azure-edition-core'
  'microsoftwindowsserver:windowsserver:2022-datacenter-azure-edition'
  'microsoftwindowsserver:windowsserver:2019-datacenter-gensecond'
  'microsoftwindowsserver:windowsserver:2019-datacenter-core-g2'
  'microsoftsqlserver:sql2022-ws2022:enterprise-gen2'
  'microsoftsqlserver:sql2022-ws2022:standard-gen2'
])
param imageURN string
param skuVersion string = 'latest'
@allowed([ 'v2' ])
param hyperVGeneration string = 'v2'

// As of April 1, 2025, the following images are available in the Azure Local Marketplace.
// | Name | Publisher | Offer | SKU |
// |------|-----------|-------|------|
// | Windows 11 Enterprise multi-session + Microsoft 365 | microsoftwindowsdesktop | office-365 | win11-23h2-avd-m365 
 win11-24h2-avd-m365 |
// | Windows 10 Enterprise multi-session + Microsoft 365  | microsoftwindowsdesktop | office-365 | win10-21h2-avd-m365 |
// | Windows 11 Pro | microsoftwindowsdesktop | windows-11 | win11-23h2-pro |
// | Windows 11 Enterprise | microsoftwindowsdesktop | windows-11 | win11-22h2-ent
win11-23h2-ent
win11-24h2-ent |
// | Windows 11 Enterprise multi-session | microsoftwindowsdesktop | windows-11 | win11-22h2-avd
win11-23h2-avd
win11-24h2-avd |
// | Windows 10 Pro | microsoftwindowsdesktop | windows-10 | win10-22h2-pro-g2 |
// | Windows 10 Enterprise | microsoftwindowsdesktop | windows-10 | win10-22h2-ent-g2 |
// | Windows 10 Enterprise multi-session | microsoftwindowsdesktop | windows-10 | win10-22h2-avd |
// | Windows Server 2025 Datacenter: Azure Edition  | microsoftwindowsserver  | windowsserver  | 2025-datacenter-azure-edition-smalldisk
2025-datacenter-azure-edition-core
2025-datacenter-azure-edition |
// | Windows Server 2022 Datacenter: Azure Edition | microsoftwindowsserver | windowsserver | 2022-datacenter-azure-edition-hotpatch
2022-datacenter-azure-edition-core
2022-datacenter-azure-edition |
// | Windows Server 2019 | microsoftwindowsserver | windowsserver | 2019-datacenter-gensecond
2019-datacenter-core-g2 |
// | SQL Server 2022 Enterprise on Windows Server 2022 | microsoftsqlserver | sql2022-ws2022 | enterprise-gen2
standard-gen2 |


var customLocationId = resourceId('Microsoft.ExtendedLocation/customLocations', customLocationName)
var publisherId = split(imageURN, ':')[0]
var offerId = split(imageURN, ':')[1]
var planId = split(imageURN, ':')[2]

resource image 'microsoft.azurestackhci/marketplacegalleryimages@2021-09-01-preview' = {
  extendedLocation: {
    name: customLocationId
    type: 'CustomLocation'
  }
  location: location
  name: imageName
  properties: {
    osType: osType
    resourceName: imageName
    hyperVGeneration: hyperVGeneration
    identifier: {
      publisher: publisherId
      offer: offerId
      sku: planId
    }
    version: {
      name: skuVersion
    }
  }
  tags: {}
}
 
