@description('Provide a type for the storage account.')
param storageAccountType string

@description('Provide a prefix name for the storage account.')
param storageAccountPrefix string = 'sa'

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

@description('SSH Public Key')
param adminPublicKey string

@description('The virtual machine size for the User Pool.')
param nodeSize string = 'Standard_D4s_v3'

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
  }
}

// Create a Managed User Identity for the Pods
module podIdentity 'modules/user_identity.bicep' = {
  name: 'user_identity_pod'
  params: {
    name: '${uniqueString(resourceGroup().id)}-pod'
  }
}

// Create Log Analytics Workspace
module logAnalytics 'modules/azure_log_analytics.bicep' = {
  name: 'log_analytics'
  params: {
    name: '${uniqueString(resourceGroup().id)}-logs'
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
    workspaceId: logAnalytics.outputs.Id
    addressPrefix: virtualNetworkAddressPrefix
    clusterSubnet: subnetAddressPrefix
    clusterSubnetName: subnetName
    podSubnet: podSubnetAddressPrefix
    podSubnetName: podSubnetName
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
    version: aksVersion
    nodeSize: nodeSize
    nodeCount: nodeCount
    identityId: clusterIdentity.outputs.resourceId
    workspaceId: logAnalytics.outputs.Id
    subnetId: subnetId
    podSubnetId: podSubnetId
    adminPublicKey: adminPublicKey
  }
  dependsOn: [
    clusterIdentity
    logAnalytics
    vnet
  ]
}
