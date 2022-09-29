targetScope = 'resourceGroup'

@minLength(3)
@maxLength(24)
@description('Resource Name.')
param prefix string = 'plt'

@description('Resource Location.')
param location string = resourceGroup().location

@description('Enable lock to prevent accidental deletion')
param enableDeleteLock bool = false

@description('Tags.')
param tags object = {}

@description('Specifies the storage account type.')
@allowed([
  'Standard_LRS'
  'Premium_LRS'
  'Standard_GRS'
])
param type string = 'Standard_LRS'


var cleanPrefix = substring(prefix, 0, min(length(prefix), 5))
var unique = uniqueString(resourceGroup().id)
var name = '${cleanPrefix}${unique}'


// Create Storage Account
resource storage 'Microsoft.Storage/storageAccounts@2021-04-01' = {
  name: replace('${name}', '-', '')
  location: location
  tags: tags
  sku: {
    name: type
  }
  kind: 'StorageV2'
  properties: {
    accessTier: 'Hot'

    networkAcls: enablePrivateLink ? {
      bypass: 'AzureServices'
      defaultAction: 'Deny'
    } : {}
  }
}

// Lock Resource
resource lock 'Microsoft.Authorization/locks@2017-04-01' = if (enableDeleteLock) {
  scope: storage

  name: '${storage.name}-lock'
  properties: {
    level: 'CanNotDelete'
  }
}

////////////////
// Private Link
////////////////

@description('Settings Required to Enable Private Link')
param privateLinkSettings object = {
  subnetId: null // Specify the Subnet for Private Endpoint
  vnetId: null // Specify the Virtual Network for Virtual Network Link
}

var enablePrivateLink = privateLinkSettings.vnetId != 'null' && privateLinkSettings.subnetId != 'null'

@description('Specifies the name of the private link to the Azure Container Registry.')
param privateEndpointName string = 'storagePrivateEndpoint'

var publicDNSZoneForwarder = 'blob.${environment().suffixes.storage}'
var privateDnsZoneName = 'privatelink.${publicDNSZoneForwarder}'

resource privateDNSZone 'Microsoft.Network/privateDnsZones@2020-06-01' = if (privateLinkSettings.subnetId != null && privateLinkSettings.vnetId != null) {
  name: privateDnsZoneName
  location: 'global'
  properties: {}
}

resource privateEndpoint 'Microsoft.Network/privateEndpoints@2022-01-01' = if (privateLinkSettings.subnetId != null && privateLinkSettings.vnetId != null) {
  name: privateEndpointName
  location: location
  properties: {
    privateLinkServiceConnections: [
      {
        name: privateEndpointName
        properties: {
          privateLinkServiceId: storage.id
          groupIds: [
            'blob'
          ]
        }
      }
    ]
    subnet: {
      id: privateLinkSettings.subnetId
    }
  }
  dependsOn: [
    storage
  ]
}

resource privateDNSZoneGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2020-06-01' = if (privateLinkSettings.vnetId != null && privateLinkSettings.subnetId != null) {
  name: '${privateEndpoint.name}/dnsgroupname'
  properties: {
    privateDnsZoneConfigs: [
      {
        name: 'dnsConfig'
        properties: {
          privateDnsZoneId: privateDNSZone.id
        }
      }
    ]
  }
  dependsOn: [
    privateDNSZone
  ]
}

#disable-next-line BCP081
resource virtualNetworkLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2022-01-01' = if (privateLinkSettings.vnetId != null && privateLinkSettings.subnetId != null) {
  parent: privateDNSZone
  name: 'link_to_vnet'
  location: 'global'
  properties: {
    registrationEnabled: false
    virtualNetwork: {
      id: privateLinkSettings.vnetId
    }
  }
  dependsOn: [
    privateDNSZone
  ]
}
