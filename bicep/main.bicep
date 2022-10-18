@description('Specify the Azure region to place the application definition.')
param location string = resourceGroup().location


/*
 __   _______   _______ .__   __. .___________. __  .___________.____    ____ 
|  | |       \ |   ____||  \ |  | |           ||  | |           |\   \  /   / 
|  | |  .--.  ||  |__   |   \|  | `---|  |----`|  | `---|  |----` \   \/   /  
|  | |  |  |  ||   __|  |  . `  |     |  |     |  |     |  |       \_    _/   
|  | |  '--'  ||  |____ |  |\   |     |  |     |  |     |  |         |  |     
|__| |_______/ |_______||__| \__|     |__|     |__|     |__|         |__|     
                                                                              */

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


/*
     _______.___________.  ______   .______          ___       _______  _______ 
    /       |           | /  __  \  |   _  \        /   \     /  _____||   ____|
   |   (----`---|  |----`|  |  |  | |  |_)  |      /  ^  \   |  |  __  |  |__   
    \   \       |  |     |  |  |  | |      /      /  /_\  \  |  | |_ | |   __|  
.----)   |      |  |     |  `--'  | |  |\  \----./  _____  \ |  |__| | |  |____ 
|_______/       |__|      \______/  | _| `._____/__/     \__\ \______| |_______|
                                                                                
*/

@description('Provide a type for the storage account.')
param storageAccountType string

@description('Provide a prefix name for the storage account.')
param storageAccountPrefix string = 'sa'

module stgModule 'br:managedplatform.azurecr.io/bicep/modules/platform/azure-storage:1.0.1' = {
  name: 'azure_storage'
  params: {
    prefix: storageAccountPrefix
    sku: storageAccountType
    location: location
  }
}



/*
 __  ___  ___________    ____ ____    ____  ___      __    __   __      .___________.
|  |/  / |   ____\   \  /   / \   \  /   / /   \    |  |  |  | |  |     |           |
|  '  /  |  |__   \   \/   /   \   \/   / /  ^  \   |  |  |  | |  |     `---|  |----`
|    <   |   __|   \_    _/     \      / /  /_\  \  |  |  |  | |  |         |  |     
|  .  \  |  |____    |  |        \    / /  _____  \ |  `--'  | |  `----.    |  |     
|__|\__\ |_______|   |__|         \__/ /__/     \__\ \______/  |_______|    |__|     
                                                                                     
*/
module keyvault 'br:managedplatform.azurecr.io/bicep/modules/platform/azure-keyvault:1.0.1' = {
  name: 'azure_keyvault'
  params: {
      resourceName: 'kv-${uniqueString(resourceGroup().id)}'
      location: location
  }
}


/*
.___  ___.   ______   .__   __.  __  .___________.  ______   .______       __  .__   __.   _______ 
|   \/   |  /  __  \  |  \ |  | |  | |           | /  __  \  |   _  \     |  | |  \ |  |  /  _____|
|  \  /  | |  |  |  | |   \|  | |  | `---|  |----`|  |  |  | |  |_)  |    |  | |   \|  | |  |  __  
|  |\/|  | |  |  |  | |  . `  | |  |     |  |     |  |  |  | |      /     |  | |  . `  | |  | |_ | 
|  |  |  | |  `--'  | |  |\   | |  |     |  |     |  `--'  | |  |\  \----.|  | |  |\   | |  |__| | 
|__|  |__|  \______/  |__| \__| |__|     |__|      \______/  | _| `._____||__| |__| \__|  \______|                                                                                                    
*/

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



/*
.__   __.  _______ .___________.____    __    ____  ______   .______       __  ___ 
|  \ |  | |   ____||           |\   \  /  \  /   / /  __  \  |   _  \     |  |/  / 
|   \|  | |  |__   `---|  |----` \   \/    \/   / |  |  |  | |  |_)  |    |  '  /  
|  . `  | |   __|      |  |       \            /  |  |  |  | |      /     |    <   
|  |\   | |  |____     |  |        \    /\    /   |  `--'  | |  |\  \----.|  .  \  
|__| \__| |_______|    |__|         \__/  \__/     \______/  | _| `._____||__|\__\ 
*/
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

var vnetId = {
  new: resourceId('Microsoft.Network/virtualNetworks', virtualNetworkName)
  existing: resourceId(virtualNetworkResourceGroup, 'Microsoft.Network/virtualNetworks', virtualNetworkName)
}

var subnetId = '${vnetId[virtualNetworkNewOrExisting]}/subnets/${subnetName}'

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

/*
.______       _______   _______  __       _______.___________..______     ____    ____ 
|   _  \     |   ____| /  _____||  |     /       |           ||   _  \    \   \  /   / 
|  |_)  |    |  |__   |  |  __  |  |    |   (----`---|  |----`|  |_)  |    \   \/   /  
|      /     |   __|  |  | |_ | |  |     \   \       |  |     |      /      \_    _/   
|  |\  \----.|  |____ |  |__| | |  | .----)   |      |  |     |  |\  \----.   |  |     
| _| `._____||_______| \______| |__| |_______/       |__|     | _| `._____|   |__|     
                                                                                                                             
*/

module acr 'br:managedplatform.azurecr.io/bicep/modules/platform/container-registry:1.0.2' = {
  name: 'container_registry'
  params: {
    resourceName: 'acr${uniqueString(resourceGroup().id)}'
    location: location
    sku: 'Premium'
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

var imageNames = [
  'mcr.microsoft.com/azuredocs/azure-vote-front:v1'
  'mcr.microsoft.com/oss/bitnami/redis:6.0.8'
]

module acrImport 'br/public:deployment-scripts/import-acr:2.0.1' = if (!empty(imageNames)) {
  name: 'imageImport'
  params: {
    acrName: acr.outputs.name
    location: location
    images: imageNames
  }
}

module acrPool 'modules/acragentpool.bicep' = {
  name: 'acrprivatepool'
  params: {
    acrName: acr.outputs.name
    acrPoolSubnetId: subnetId
    location: location
  }
}


/*
 __  ___  __    __  .______    _______ .______      .__   __.  _______ .___________. _______     _______.
|  |/  / |  |  |  | |   _  \  |   ____||   _  \     |  \ |  | |   ____||           ||   ____|   /       |
|  '  /  |  |  |  | |  |_)  | |  |__   |  |_)  |    |   \|  | |  |__   `---|  |----`|  |__     |   (----`
|    <   |  |  |  | |   _  <  |   __|  |      /     |  . `  | |   __|      |  |     |   __|     \   \    
|  .  \  |  `--'  | |  |_)  | |  |____ |  |\  \----.|  |\   | |  |____     |  |     |  |____.----)   |   
|__|\__\  \______/  |______/  |_______|| _| `._____||__| \__| |_______|    |__|     |_______|_______/    
                                                                                                         
*/
@description('The virtual machine size for the User Pool.')
param vmSize string = 'Standard_DS3_v2'

@description('The number of nodes in the User Pool.')
param nodeCount int = 3


module cluster 'modules/aks_cluster.bicep' = {
  name: 'azure_kubernetes'
  params: {
    // Basic Details
    resourceName: 'aks-${uniqueString(resourceGroup().id)}'
    location: location
    aad_tenant_id: subscription().tenantId

    // Configure Linking Items
    subnetId: subnetId
    identityId: clusterIdentity.outputs.id
    workspaceId: logAnalytics.outputs.id

    // Configure NodePools
    JustUseSystemPool: false
    SystemPoolType: 'CostOptimised'
    vmSize: vmSize
    agentCount: nodeCount

    // Configure Add Ons
    enable_aad: true
    enableAzureRBAC : true
    workloadIdentityEnabled: true
    keyvaultEnabled: true
    fluxGitOpsAddon:true
  }
  dependsOn: [
    clusterIdentity
    logAnalytics
    vnet
  ]
}

output aksName string = cluster.outputs.name


module aadWorkloadId 'modules/workloadId.bicep' = {
  name: 'aadWorkloadId-helm'
  params: {
    aksName: cluster.outputs.name
    location: location
  }
}


//--------------Flux Config---------------
module flux 'modules/flux_config_unified.bicep' = {
  name: 'flux'
  params: {
    aksName: cluster.outputs.name
    aksFluxAddOnReleaseNamespace: cluster.outputs.fluxReleaseNamespace
    fluxConfigRepo: 'https://github.com/mspnp/aks-baseline'
  }
}
