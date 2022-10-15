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

@description('Specify the cluster pods subnet.')
param podSubnetId string

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


@description('Specify the Network Settings')
param networkSettings object = {
  networkPlugin: 'azure' // Specifies the network plugin used for building Kubernetes network. - azure or kubenet.
  networkPolicy: 'calico' // Specifies the network policy used for building Kubernetes network. - calico or azure
  networkMode: 'overlay'  // Specifies the network mode for Azure CNI Overlay
  podCidr: '10.240.100.0/22' // Specifies the CIDR notation IP range from which to assign pod IPs when kubenet is used.
  serviceCidr: '172.10.0.0/16' // Must be cidr not in use any where else across the Network (Azure or Peered/On-Prem).  Can safely be used in multiple clusters - presuming this range is not broadcast/advertised in route tables.
  dnsServiceIP: '172.10.0.10' // Ip Address for K8s DNS
  dockerBridgeCidr: '172.17.0.1/16' // Used for the default docker0 bridge network that is required when using Docker as the Container Runtime.  Not used by AKS or Docker and is only cluster-routable.  Cluster IP based addresses are allocated from this range.  Can be safely reused in multiple clusters.
  outboundType: 'loadBalancer' // Specifies outbound (egress) routing method. - loadBalancer or userDefinedRouting.
  loadBalancerSku: 'standard' // Specifies the sku of the load balancer used by the virtual machine scale sets used by nodepools.
}

@description('Specify the API Server Access Settings')
param apiSettings object = {
  privateCluster: false // Specifies whether to create the cluster as a private cluster or not.
  privateClusterPublicFQDN: false // If true, the cluster will have a private DNS name.  If false, the cluster will have a public DNS name.// Specifies whether to create additional public FQDN for private cluster or not.
  privateDNSZone: '' // Specifies the Private DNS Zone mode for private cluster. When the value is equal to None, a Public DNS Zone is used in place of a Private DNS Zone
}

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
  podSubnetID: podSubnetId
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
  podSubnetID: podSubnetId
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
  fluxEnabled: true // Specifies whether the flux add-on is enabled or not.
}

var name = 'aks-${uniqueString(resourceGroup().id, resourceName)}'

resource aks 'Microsoft.ContainerService/managedClusters@2022-07-02-preview' = {
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
      networkPlugin: networkSettings.networkPlugin
      networkPolicy: networkSettings.networkPolicy
      networkPluginMode: networkSettings.networkPlugin=='azure' ? networkSettings.networkPluginMode : ''
      podCidr: networkSettings.podCidr
      serviceCidr: networkSettings.serviceCidr
      dnsServiceIP: networkSettings.dnsServiceIP
      dockerBridgeCidr: networkSettings.dockerBridgeCidr
      outboundType: networkSettings.outboundType
      loadBalancerSku: networkSettings.loadBalancerSku
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

    apiServerAccessProfile: {
      enablePrivateCluster: apiSettings.privateCluster
      privateDNSZone: apiSettings.privateDNSZone
      enablePrivateClusterPublicFQDN: apiSettings.privateClusterPublicFQDN
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


resource fluxAddon 'Microsoft.KubernetesConfiguration/extensions@2022-04-02-preview' = if(addOn.fluxEnabled) {
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

output name string = aks.name
