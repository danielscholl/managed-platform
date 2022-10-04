targetScope = 'resourceGroup'

@minLength(5)
@maxLength(50)
@description('Registry Name.')
param name string = 'acr${uniqueString(resourceGroup().id)}'

@description('Registry Location.')
param location string = resourceGroup().location

@description('Enable lock to prevent accidental deletion')
param enableDeleteLock bool = false

@description('Tags.')
param tags object = {}

@description('Enable an admin user that has push/pull permission to the registry.')
param acrAdminUserEnabled bool = false

@description('Tier of your Azure Container Registry.')
@allowed([
  'Basic'
  'Standard'
  'Premium'
])
param acrSku string = 'Premium'


// Create Azure Container Registry
resource acr 'Microsoft.ContainerRegistry/registries@2019-12-01-preview' = {
  name: replace('${name}', '-', '')
  location: location
  tags: tags
  sku: {
    name: acrSku
  }
  properties: {
    adminUserEnabled: acrAdminUserEnabled
  }
}

// ACR Resource Locking
resource lock 'Microsoft.Authorization/locks@2016-09-01' = if (enableDeleteLock) {
  scope: acr

  name: '${acr.name}-lock'
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

@description('Specifies the name of the private link to the Azure Container Registry.')
param privateEndpointName string = 'acrPrivateEndpoint'

var privateDnsZoneName = 'privatelink.${publicDNSZoneForwarder}'
var publicDNSZoneForwarder = ((toLower(environment().name) == 'azureusgovernment') ? 'azurecr.us' : 'azurecr.io')

resource privateDNSZone 'Microsoft.Network/privateDnsZones@2020-06-01' = if (acrSku == 'Premium' && privateLinkSettings.subnetId != null && privateLinkSettings.vnetId != null) {
  name: privateDnsZoneName
  location: 'global'
  properties: {}
}

resource privateEndpoint 'Microsoft.Network/privateEndpoints@2020-07-01' = if (acrSku == 'Premium' && privateLinkSettings.subnetId != null && privateLinkSettings.vnetId != null) {
  name: privateEndpointName
  location: location
  properties: {
    privateLinkServiceConnections: [
      {
        name: privateEndpointName
        properties: {
          privateLinkServiceId: acr.id
          groupIds: [
            'registry'
          ]
        }
      }
    ]
    subnet: {
      id: privateLinkSettings.subnetId
    }
  }
  dependsOn: [
    acr
  ]
}

resource privateDNSZoneGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2020-06-01' = if (acrSku == 'Premium' && privateLinkSettings.subnetId != null && privateLinkSettings.vnetId != null) {
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
}

resource virtualNetworkLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = if (acrSku == 'Premium' && privateLinkSettings.subnetId != null && privateLinkSettings.vnetId != null) {
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

output acrLoginServer string = acr.properties.loginServer
output acrName string = acr.name
