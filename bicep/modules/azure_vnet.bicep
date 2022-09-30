targetScope = 'resourceGroup'

@description('Resource Name.')
param name string = 'net${resourceGroup().name}'

@description('Resource Location.')
param location string = resourceGroup().location

@description('Resource Tags (Optional).')
param tags object = {}

@description('Enable lock to prevent accidental deletion')
param enableDeleteLock bool = false

@description('Specify Log Workspace to Enable Diagnostics (Optional).')
param workspaceId string = 'null'

@description('Virtual Network Address CIDR')
param addressPrefix string = '10.0.0.0/16'

@description('Cluster Node Subnet Address CIDR')
param clusterSubnet string = '10.0.1.0/24'

@description('Cluster Node Subnet Address Name')
param clusterSubnetName string = 'NodeSubnet'

@description('Pod Subnet Address CIDR')
param podSubnet string = '10.0.2.0/24'

@description('Pod Subnet Address Name')
param podSubnetName string = 'PodSubnet'

@description('Array of objects that describe RBAC permissions, format { roleDefinitionResourceId (string), principalId (string), principalType (enum), enabled (bool) }. Ref: https://docs.microsoft.com/en-us/azure/templates/microsoft.authorization/roleassignments?tabs=bicep')
param rbacPermissions array = [
  /* example
      {
        roleDefinitionResourceId: '/providers/Microsoft.Authorization/roleDefinitions/00482a5a-887f-4fb3-b363-3b7fe8e74483' // Key Vault Administrator
        principalId: '00000000-0000-0000-0000-000000000000' // az ad signed-in-user show --query objectId --output tsv
        principalType: 'User'
        enabled: false
      }
  */
]

// Create a Virtual Network
resource vnet 'Microsoft.Network/virtualNetworks@2021-02-01' = {
  name: name
  location: location
  tags: tags
  properties: {
    addressSpace: {
      addressPrefixes: [
        addressPrefix
      ]
    }
    subnets: [
      {
        name: clusterSubnetName
        properties: {
          addressPrefix: clusterSubnet
          privateEndpointNetworkPolicies: 'Disabled'
          privateLinkServiceNetworkPolicies: 'Enabled'
        }
      }
      {
        // Pod Subnet should have traffic routed out of a Firewall.
        name: podSubnetName
        properties: {
          addressPrefix: podSubnet
          privateEndpointNetworkPolicies: 'Disabled'
          privateLinkServiceNetworkPolicies: 'Enabled'
        }
      }
    ]
  }
}

// Apply Resource Lock
resource lock 'Microsoft.Authorization/locks@2016-09-01' = if (enableDeleteLock) {
  scope: vnet

  name: '${vnet.name}-lock'
  properties: {
    level: 'CanNotDelete'
  }
}



// Hook up Vnet Diagnostics
resource vnetDiagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = if (workspaceId != 'null') {
  name: 'vnet-diagnostics'
  scope: vnet
  properties: {
    workspaceId: workspaceId
    logs: [
      {
        category: 'VMProtectionAlerts'
        enabled: true
        retentionPolicy: {
          enabled: false
          days: 0
        }
      }
    ]
  }
  dependsOn: [
    vnet
  ]
}

// Add role assignments
resource roleAssignment 'Microsoft.Authorization/roleAssignments@2020-08-01-preview' = [for item in rbacPermissions: if (item.enabled) {
  name: guid(vnet.id, item.principalId, item.roleDefinitionResourceId)
  scope: vnet
  properties: {
    roleDefinitionId: item.roleDefinitionResourceId
    principalId: item.principalId
    principalType: item.principalType
  }
}]

output vnetId string = vnet.id
output clusterSubnetId string = resourceId('Microsoft.Network/virtualNetworks/subnets', name, clusterSubnetName)
output podSubnetId string = resourceId('Microsoft.Network/virtualNetworks/subnets', name, podSubnetName)
