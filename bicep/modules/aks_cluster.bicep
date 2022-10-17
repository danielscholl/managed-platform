targetScope = 'resourceGroup'

@minLength(1)
@maxLength(63)
@description('Used to name all resources')
param resourceName string

@description('Specify the location of the AKS cluster.')
param location string = resourceGroup().location

@description('Specify the amount of nodes for the User Node Pool.')
param nodeCount int = 3

@description('Specify the Server Size for the User Node Pool.')
param vmSize string = 'Standard_D4s_v3'

@description('Specify the cluster nodes subnet.')
param subnetId string

@description('Specify the Log Analytics Workspace Id to use for monitoring.')
param workspaceId string

@description('Specify the User Managed Identity Resource Id.')
param identityId string

@description('Specifies the DNS prefix specified when creating the managed cluster.')
param dnsPrefix string = 'aks-${resourceGroup().name}'

@description('Specifies the tier of a managed cluster SKU: Paid or Free')
@allowed([
  'Paid'
  'Free'
])
param skuTier string = 'Free'

@description('Specifies the version of Kubernetes specified when creating the managed cluster.')
param version string = '1.24.3'

@description('Specifies the upgrade channel for auto upgrade. Allowed values include rapid, stable, patch, node-image, none.')
@allowed([
  'rapid'
  'stable'
  'patch'
  'node-image'
  'none'
])
param aksUpgradeChannel string = 'stable'


@allowed([
  'azure'
  'kubenet'
])
@description('The network plugin type')
param networkPlugin string = 'azure'

@allowed([
  ''
  'Overlay'
])
@description('The network plugin type')
param networkPluginMode string = ''

@allowed([
  ''
  'azure'
  'calico'
])
@description('The network policy to use.')
param networkPolicy string = ''

@minLength(9)
@maxLength(18)
@description('The address range to use for pods')
param podCidr string = '10.240.100.0/22'

@description('Allocate pod ips dynamically')
param cniDynamicIpAllocation bool = false

@minLength(9)
@maxLength(18)
@description('The address range to use for services')
param serviceCidr string = '172.10.0.0/16'

@minLength(7)
@maxLength(15)
@description('The IP address to reserve for DNS')
param dnsServiceIP string = '172.10.0.10'

@minLength(9)
@maxLength(18)
@description('The address range to use for the docker bridge')
param dockerBridgeCidr string = '172.17.0.1/16'

@allowed([
  'loadBalancer'
  'managedNATGateway'
  'userAssignedNATGateway'
])
@description('Outbound traffic type for the egress traffic of your cluster')
param aksOutboundTrafficType string = 'loadBalancer'


// API Server Access Settings
@description('The IP addresses that are allowed to access the API server')
param authorizedIPRanges array = []

@description('Enable private cluster')
param enablePrivateCluster bool = false

@allowed([
  'system'
  'none'
  'privateDnsZone'
])
@description('Private cluster dns advertisment method, leverages the dnsApiPrivateZoneId parameter')
param privateClusterDnsMethod string = 'system'

@description('The full Azure resource ID of the privatelink DNS zone to use for the AKS cluster API Server')
param dnsApiPrivateZoneId string = ''

@description('Sets the private dns zone id if provided')
var aksPrivateDnsZone = privateClusterDnsMethod=='privateDnsZone' ? (!empty(dnsApiPrivateZoneId) ? dnsApiPrivateZoneId : 'system') : privateClusterDnsMethod
output aksPrivateDnsZone string = aksPrivateDnsZone

@description('Specify the AutoScale Settings')
param scalerSettings object = {
  scanInterval: '10s'
  scaleDownDelayAfterAdd: '10m'
  scaleDownDelayAfterDelete: '20s'
  scaleDownDelayAfterFailure: '3m'
  scaleDownUnneededTime: '10m'
  scaleDownUnreadyTime: '20m'
  utilizationThreshold: '0.5'
  maxGracefulTerminationSec: '600'
}

@description('Specify the System Node Pool Settings')
param defaultNodePool object = {
  name: 'systempool01'
  count: 3
  vmSize: 'Standard_D2s_v3'
  osDiskSizeGB: 50
  osDiskType: 'Ephemeral'
  maxPods: 30
  osType: 'Linux'
  maxCount: 5
  minCount: 3
  scaleSetPriority: 'Regular'
  scaleSetEvictionPolicy: 'Delete'
  enableAutoScaling: true
  mode: 'System'
  type: 'VirtualMachineScaleSets'
  availablityZones: [
    '1'
    '2'
    '3'
  ]
  nodeTaints: [
    'CriticalAddonsOnly=true:NoSchedule'
  ]
  vnetSubnetID: subnetId
}

@description('Specify the User Node Pool Settings')
param userNodePool object = {
  name: 'nodepool1'
  count: nodeCount
  vmSize: vmSize
  osDiskSizeGB: 100
  osDiskType: 'Ephemeral'
  maxPods: 30
  osType: 'Linux'
  maxCount: 5
  minCount: 3
  scaleSetPriority: 'Regular'
  scaleSetEvictionPolicy: 'Delete'
  enableAutoScaling: true
  mode: 'User'
  type: 'VirtualMachineScaleSets'
  availablityZones: [
    '1'
    '2'
    '3'
  ]
  vnetSubnetID: subnetId
}



// AKS Feature Add On Configurations
var addOn = {
  aciConnectorLinuxEnabled: false // Specifies whether the aciConnectorLinux add-on is enabled or not.
  azurePolicyEnabled: true // Specifies whether the azurePolicy add-on is enabled or not.
  kubeDashboardEnabled: false // Specifies whether the kubeDashboard add-on is enabled or not.
  httpApplicationRoutingEnabled: true // Specifies whether the httpApplicationRouting add-on is enabled or not.
  podIdentityProfileEnabled: false // Specifies whether the podIdentityProfile add-on is enabled or not.
  kvCsiDriverEnabled: true // Specifies whether the kvCsiDriver add-on is enabled or not.
  kedaEnabled: true // Specifies whether the keda add-on is enabled or not.
  oidcEnabled: true // Specifies whether the oidc issuer add-on is enabled or not.
  defenderEnabled: true // Specifies whether the defender add-on is enabled or not.
  meshEnabled: true // Specifies whether the Open Serivce Mesh add-on is enabled or not.
}

var name = 'aks-${uniqueString(resourceGroup().id, resourceName)}'

resource aks 'Microsoft.ContainerService/managedClusters@2022-08-03-preview' = {
  name: length(name) > 63 ? substring(name, 0, 63) : name
  location: location

  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${identityId}': {}
    }
  }

  sku: {
    name: 'Basic'
    tier: skuTier
  }

  properties: {
    kubernetesVersion: version
    nodeResourceGroup: 'MC_${resourceGroup().name}_${name}'
    dnsPrefix: dnsPrefix

    agentPoolProfiles: [
      defaultNodePool
      userNodePool
    ]

    addonProfiles: {
      httpApplicationRouting: {
        enabled: addOn.httpApplicationRoutingEnabled
      }
      omsagent: {
        enabled: true
        config: {
          logAnalyticsWorkspaceResourceID: workspaceId
        }
      }
      aciConnectorLinux: {
        enabled: addOn.aciConnectorLinuxEnabled
      }
      azurepolicy: {
        enabled: addOn.azurePolicyEnabled
        config: {
          version: 'v2'
        }
      }
      kubeDashboard: {
        enabled: addOn.kubeDashboardEnabled
      }
      azurekeyvaultsecretsprovider: {
        enabled: addOn.kvCsiDriverEnabled
      }
      openServiceMesh: {
        enabled: addOn.meshEnabled
      }
    }

      podIdentityProfile: {
        enabled: addOn.podIdentityProfileEnabled
      }

      networkProfile: {
        loadBalancerSku: 'standard'
        networkPlugin: networkPlugin
        #disable-next-line BCP036 //Disabling validation of this parameter to cope with empty string to indicate no Network Policy required.
        networkPolicy: networkPolicy
        networkPluginMode: networkPlugin=='azure' ? networkPluginMode : ''
        podCidr: networkPlugin=='kubenet' || cniDynamicIpAllocation ? podCidr : json('null')
        serviceCidr: serviceCidr
        dnsServiceIP: dnsServiceIP
        dockerBridgeCidr: dockerBridgeCidr
        outboundType: aksOutboundTrafficType
      }

    enableRBAC: true

    autoUpgradeProfile: {
      upgradeChannel: aksUpgradeChannel
    }

    autoScalerProfile: {
      'scan-interval': scalerSettings.scanInterval
      'scale-down-delay-after-add': scalerSettings.scaleDownDelayAfterAdd
      'scale-down-delay-after-delete': scalerSettings.scaleDownDelayAfterDelete
      'scale-down-delay-after-failure': scalerSettings.scaleDownDelayAfterFailure
      'scale-down-unneeded-time': scalerSettings.scaleDownUnneededTime
      'scale-down-unready-time': scalerSettings.scaleDownUnreadyTime
      'scale-down-utilization-threshold': scalerSettings.utilizationThreshold
      'max-graceful-termination-sec': scalerSettings.maxGracefulTerminationSec
    }

    apiServerAccessProfile: !empty(authorizedIPRanges) ? {
    authorizedIPRanges: authorizedIPRanges
  } : {
    enablePrivateCluster: enablePrivateCluster
    privateDNSZone: enablePrivateCluster ? aksPrivateDnsZone : ''
    enablePrivateClusterPublicFQDN: enablePrivateCluster && privateClusterDnsMethod=='none'
  }
  
    workloadAutoScalerProfile: {
      keda: {
        enabled: addOn.kedaEnabled
      }
    }

    oidcIssuerProfile: {
      enabled: addOn.oidcEnabled
    }

    securityProfile: {
      defender: {
        logAnalyticsWorkspaceResourceId: addOn.defenderEnabled ? workspaceId : null
        securityMonitoring: {
          enabled: addOn.defenderEnabled
        }
      }
    }
    storageProfile: {
      diskCSIDriver: {
        enabled: true
      }
      fileCSIDriver: {
        enabled: true
      }
      snapshotController: {
        enabled: true
      }
    }
  }
}

param fluxGitOpsAddon bool = false

resource fluxAddon 'Microsoft.KubernetesConfiguration/extensions@2022-04-02-preview' = if(fluxGitOpsAddon) {
  name: 'flux'
  scope: aks
  properties: {
    extensionType: 'microsoft.flux'
    autoUpgradeMinorVersion: true
    releaseTrain: 'Stable'
    scope: {
      cluster: {
        releaseNamespace: 'flux-system'
      }
    }
    configurationProtectedSettings: {}
  }
  dependsOn: [aks]
}
output fluxReleaseNamespace string = fluxGitOpsAddon ? fluxAddon.properties.scope.cluster.releaseNamespace : ''


// resource fluxAddon 'Microsoft.KubernetesConfiguration/extensions@2022-04-02-preview' = if(addOn.fluxEnabled) {
//   name: 'flux'
//   scope: aks
//   properties: {
//     extensionType: 'microsoft.flux'
//     autoUpgradeMinorVersion: true
//     releaseTrain: 'Stable'
//     scope: {
//       cluster: {
//         releaseNamespace: 'flux-system'
//       }
//     }
//     configurationProtectedSettings: {}
//   }
//   dependsOn: [aks]
// }

output name string = aks.name
