@description('Provide a type for the storage account.')
param storageAccountType string

@description('Provide a prefix name for the storage account.')
param storageAccountPrefix string = 'sa'

param storagePrivateLink bool = false

@description('Specify the Azure region to place the application definition.')
param location string = resourceGroup().location

@description('Name of the Virtual Network')
param virtualNetworkName string = '${uniqueString(resourceGroup().id)}-network'

@description('Boolean indicating whether the VNet is new or existing')
param virtualNetworkNewOrExisting string = 'new'

@description('VNet address prefix')
param virtualNetworkAddressPrefix string = '10.1.0.0/16'

@description('Resource group of the VNet')
param virtualNetworkResourceGroup string = ''

@description('New or Existing subnet Name')
param subnetName string = 'NodeSubnet'

@description('Subnet address prefix')
param subnetAddressPrefix string = '10.1.0.0/24'

@description('New or Existing subnet Name')
param podSubnetName string = 'PodSubnet'

@description('Subnet address prefix')
param podSubnetAddressPrefix string = '10.1.1.0/24'

@description('Version of the AKS Cluster')
param aksVersion string = '1.24.3'

@description('The virtual machine size for the User Pool.')
param vmSize string = 'Standard_D4s_v3'

@description('The number of nodes in the User Pool.')
param nodeCount int = 3


var vnetId = {
  new: resourceId('Microsoft.Network/virtualNetworks', virtualNetworkName)
  existing: resourceId(virtualNetworkResourceGroup, 'Microsoft.Network/virtualNetworks', virtualNetworkName)
}

var subnetId = '${vnetId[virtualNetworkNewOrExisting]}/subnets/${subnetName}'
var podSubnetId = '${vnetId[virtualNetworkNewOrExisting]}/subnets/${podSubnetName}'

module stgModule 'modules/azure_storage.bicep' = {
  name: 'azure_storage'
  params: {
    prefix: storageAccountPrefix
    type: storageAccountType
    location: location
  }
}

module keyvault 'modules/azure_keyvault.bicep' = {
  name: 'azure_keyvault'
  params: {
      name: 'kv${uniqueString(resourceGroup().id)}'
      location: location
  }
}

// Create a Managed User Identity for the Cluster
module clusterIdentity 'modules/user_identity.bicep' = {
  name: 'user_identity_cluster'
  params: {
    name: '${uniqueString(resourceGroup().id)}-cluster'
    location: location
  }
}

// Create a Managed User Identity for the Pods
module podIdentity 'modules/user_identity.bicep' = {
  name: 'user_identity_pod'
  params: {
    name: '${uniqueString(resourceGroup().id)}-pod'
    location: location
  }
}

// Create Log Analytics Workspace
module logAnalytics 'modules/azure_log_analytics.bicep' = {
  name: 'log_analytics'
  params: {
    name: '${uniqueString(resourceGroup().id)}-logs'
    location: location
    sku: 'PerGB2018'
    retentionInDays: 30
  }
  // This dependency is only added to attempt to solve a timing issue.
  // Identities sometimes list as completed but can't be used yet.
  dependsOn: [
    clusterIdentity
    podIdentity
  ]
}


// Create Virtual Network
module vnet 'modules/azure_vnet.bicep' = if (virtualNetworkNewOrExisting == 'new') {
  name: 'azure_vnet'
  params: {
    name: virtualNetworkName
    location: location
    workspaceId: logAnalytics.outputs.Id
    addressPrefix: virtualNetworkAddressPrefix
    clusterSubnet: subnetAddressPrefix
    clusterSubnetName: subnetName
    podSubnet: podSubnetAddressPrefix
    podSubnetName: podSubnetName
    rbacPermissions: [
      {
        roleDefinitionResourceId: '/providers/Microsoft.Authorization/roleDefinitions/4d97b98b-1d4f-4787-a291-c67834d212e7' // Network Contributor
        principalId: clusterIdentity.outputs.principalId
        principalType: 'ServicePrincipal'
        enabled: true
      }
    ]
  }
  dependsOn: [
    clusterIdentity
    logAnalytics
  ]
}

module cluster 'modules/aks_cluster.bicep' = {
  name: 'azure_kubernetes'
  params: {
    name: '${uniqueString(resourceGroup().id)}-cluster'
    location: location
    version: aksVersion
    vmSize: vmSize
    nodeCount: nodeCount
    identityId: clusterIdentity.outputs.resourceId
    workspaceId: logAnalytics.outputs.Id
    subnetId: subnetId
    podSubnetId: podSubnetId
  }
  dependsOn: [
    clusterIdentity
    logAnalytics
    vnet
  ]
}

output storagePrivateLink bool = storagePrivateLink
