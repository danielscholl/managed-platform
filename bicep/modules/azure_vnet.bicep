targetScope = 'resourceGroup'

@description('Resource Name.')
param name string = '${resourceGroup().name}-vnet'

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

output vnetId string = vnet.id
output clusterSubnetId string = resourceId('Microsoft.Network/virtualNetworks/subnets', name, clusterSubnetName)
output podSubnetId string = resourceId('Microsoft.Network/virtualNetworks/subnets', name, podSubnetName)
