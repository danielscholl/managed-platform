@description('Provide a type for the storage account.')
param storageAccountType string

@description('Provide a prefix name for the storage account.')
param storageAccountPrefix string = 'sa'

@description('Specify the Azure region to place the application definition.')
param location string = resourceGroup().location

@description('Name of the Virtual Network')
param virtualNetworkName string = 'vnet-${uniqueString(resourceGroup().id)}'

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

module stgModule 'br:managedplatform.azurecr.io/bicep/modules/platform/azure-storage:1.0.1' = {
  name: 'azure_storage'
  params: {
    prefix: storageAccountPrefix
    sku: storageAccountType
    location: location
  }
}

module keyvault 'br:managedplatform.azurecr.io/bicep/modules/platform/azure-keyvault:1.0.1' = {
  name: 'azure_keyvault'
  params: {
      resourceName: 'kv-${uniqueString(resourceGroup().id)}'
      location: location
  }
}

// Create a Managed User Identity for the Cluster
module clusterIdentity 'br:managedplatform.azurecr.io/bicep/modules/platform/user-identity:1.0.1' = {
  name: 'user_identity_cluster'
  params: {
    resourceName: 'id-aks-${uniqueString(resourceGroup().id)}'
    location: location
  }
}

// Create a Managed User Identity for the Pods
module podIdentity 'br:managedplatform.azurecr.io/bicep/modules/platform/user-identity:1.0.1' = {
  name: 'user_identity_pod'
  params: {
    resourceName: 'id-pod-${uniqueString(resourceGroup().id)}'
    location: location
  }
}

// Create Log Analytics Workspace
module logAnalytics 'br:managedplatform.azurecr.io/bicep/modules/platform/log-analytics:1.0.1' = {
  name: 'log_analytics'
  params: {
    resourceName: 'log-${uniqueString(resourceGroup().id)}'
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
module vnet 'br:managedplatform.azurecr.io/bicep/modules/platform/azure-vnet:1.0.1' = if (virtualNetworkNewOrExisting == 'new') {
  name: 'azure_vnet'
  params: {
    resourceName: virtualNetworkName
    location: location
    diagnosticWorkspaceId: logAnalytics.outputs.id
    addressPrefixes: [
      virtualNetworkAddressPrefix
    ]
    subnets: [
      {
        name: subnetName
        addressPrefix: subnetAddressPrefix
        privateEndpointNetworkPolicies: 'Disabled'
        privateLinkServiceNetworkPolicies: 'Enabled'
      }
    ]
    roleAssignments: [
      {
        roleDefinitionIdOrName: 'Contributor'
        principalIds: [
          clusterIdentity.outputs.principalId
        ]
        principalType: 'ServicePrincipal'
      }
    ]
  }
  dependsOn: [
    clusterIdentity
    logAnalytics
  ]
}

// Create Container Registry
module acr 'br:managedplatform.azurecr.io/bicep/modules/platform/container-registry:1.0.2' = {
  name: 'container_registry'
  params: {
    resourceName: 'acr${uniqueString(resourceGroup().id)}'
    location: location
    rbacPermissions: [
      {
        roleDefinitionResourceId: '/providers/Microsoft.Authorization/roleDefinitions/8311e382-0749-4cb8-b61a-304f252e45ec' //Acr Push Role
        principalId: clusterIdentity.outputs.principalId
        principalType: 'ServicePrincipal'
        enabled: true
      }
    ]
  }
  dependsOn: [
    clusterIdentity
    cluster
  ]
}

// Create AKS Cluster
module cluster 'modules/aks_cluster.bicep' = {
  name: 'azure_kubernetes'
  params: {
    resourceName: 'aks-${uniqueString(resourceGroup().id)}'
    location: location
    version: aksVersion
    vmSize: vmSize
    nodeCount: nodeCount
    identityId: clusterIdentity.outputs.id
    workspaceId: logAnalytics.outputs.id
    subnetId: subnetId
    podSubnetId: podSubnetId
  }
  dependsOn: [
    clusterIdentity
    logAnalytics
    vnet
  ]
}

output aksName string = cluster.outputs.name
