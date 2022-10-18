targetScope = 'resourceGroup'

/*______      ___      .______          ___      .___  ___.  _______ .___________. _______ .______          _______.
|   _  \    /   \     |   _  \        /   \     |   \/   | |   ____||           ||   ____||   _  \        /       |
|  |_)  |  /  ^  \    |  |_)  |      /  ^  \    |  \  /  | |  |__   `---|  |----`|  |__   |  |_)  |      |   (----`
|   ___/  /  /_\  \   |      /      /  /_\  \   |  |\/|  | |   __|      |  |     |   __|  |      /        \   \    
|  |     /  _____  \  |  |\  \----./  _____  \  |  |  |  | |  |____     |  |     |  |____ |  |\  \----.----)   |   
| _|    /__/     \__\ | _| `._____/__/     \__\ |__|  |__| |_______|    |__|     |_______|| _| `._____|_______/    
*/
                                                                                                                   

////////////////////
// Basic Details
////////////////////

@minLength(1)
@maxLength(63)
@description('Used to name all resources')
param resourceName string

@description('Specify the location of the AKS cluster.')
param location string = resourceGroup().location

@description('The ID of the Azure AD tenant')
param aad_tenant_id string = ''

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

@description('The zones to use for a node pool')
param availabilityZones array = []

@description('The number of agents for the user node pool')
param agentCount int = 3

@description('The maximum number of nodes for the user node pool')
param agentCountMax int = 0
var autoScale = agentCountMax > agentCount

@description('Specify the Server Size for the User Node Pool.')
param vmSize string = 'Standard_DS3_v2'

@minValue(10)
@maxValue(250)
@description('The maximum number of pods per node.')
param maxPods int = 30

@allowed([
  'Ephemeral'
  'Managed'
])
@description('OS disk type')
param osDiskType string = 'Ephemeral'

@description('Disk size in GB')
param osDiskSizeGB int = 0



////////////////////
// Compute Configuration
////////////////////

@description('Only use the system node pool')
param JustUseSystemPool bool = false

@allowed([
  'CostOptimised'
  'Standard'
  'HighSpec'
  'Custom'
])
@description('The System Pool Preset sizing')
param SystemPoolType string = 'CostOptimised'

@description('A custom system pool spec')
param SystemPoolCustomPreset object = {}

@description('The System Pool Preset sizing')
param AutoscaleProfile object = {
  'balance-similar-node-groups': 'true'
  expander: 'random'
  'max-empty-bulk-delete': '10'
  'max-graceful-termination-sec': '600'
  'max-node-provision-time': '15m'
  'max-total-unready-percentage': '45'
  'new-pod-scale-up-delay': '0s'
  'ok-total-unready-count': '3'
  'scale-down-delay-after-add': '10m'
  'scale-down-delay-after-delete': '20s'
  'scale-down-delay-after-failure': '3m'
  'scale-down-unneeded-time': '10m'
  'scale-down-unready-time': '20m'
  'scale-down-utilization-threshold': '0.5'
  'scan-interval': '10s'
  'skip-nodes-with-local-storage': 'true'
  'skip-nodes-with-system-pods': 'true'
}


////////////////////
// Required Items to link to other resources
////////////////////

@description('Specify the Log Analytics Workspace Id to use for monitoring.')
param workspaceId string

@description('Specify the User Managed Identity Resource Id.')
param identityId string

@description('Specify the cluster nodes subnet.')
param subnetId string



////////////////////
// Network Configuration
////////////////////

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

@description('Specifies the DNS prefix specified when creating the managed cluster.')
param dnsPrefix string = 'aks-${resourceGroup().name}'



////////////////////
// Security Settings
////////////////////

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

@description('The IP addresses that are allowed to access the API server')
param authorizedIPRanges array = []


@allowed([
  ''
  'audit'
  'deny'
])
@description('Enable the Azure Policy addon')
param azurepolicy string = ''



////////////////////
// Add Ons
////////////////////

@description('Enables Kubernetes Event-driven Autoscaling (KEDA)')
param kedaEnabled bool = false

@description('Enables Open Service Mesh')
param openServiceMeshEnabled bool = false

@description('Configures the cluster as an OIDC issuer for use with Workload Identity')
param workloadIdentityEnabled bool = false

@description('Configures the cluster to use Azure Defender')
param defenderEnabled bool = false

@description('Installs the AKS KV CSI provider')
param keyvaultEnabled bool = false

@description('Rotation poll interval for the AKS KV CSI provider')
param keyVaultAksCSIPollInterval string = '2m'

@description('Enable Azure AD integration on AKS')
param enable_aad bool = false

@description('Enable RBAC using AAD')
param enableAzureRBAC bool = false


/*__    ____  ___      .______       __       ___      .______    __       _______     _______.
\   \  /   / /   \     |   _  \     |  |     /   \     |   _  \  |  |     |   ____|   /       |
 \   \/   / /  ^  \    |  |_)  |    |  |    /  ^  \    |  |_)  | |  |     |  |__     |   (----`
  \      / /  /_\  \   |      /     |  |   /  /_\  \   |   _  <  |  |     |   __|     \   \    
   \    / /  _____  \  |  |\  \----.|  |  /  _____  \  |  |_)  | |  `----.|  |____.----)   |   
    \__/ /__/     \__\ | _| `._____||__| /__/     \__\ |______/  |_______||_______|_______/    
*/
                                                                                               


@description('The name of the AKS cluster.')
var name = 'aks-${uniqueString(resourceGroup().id, resourceName)}'

@description('Sets the private dns zone id if provided')
var aksPrivateDnsZone = privateClusterDnsMethod=='privateDnsZone' ? (!empty(dnsApiPrivateZoneId) ? dnsApiPrivateZoneId : 'system') : privateClusterDnsMethod
output aksPrivateDnsZone string = aksPrivateDnsZone

@description('System Pool presets are derived from the recommended system pool specs')
var systemPoolPresets = {
  CostOptimised : {
    vmSize: 'Standard_B4ms'
    count: 1
    minCount: 1
    maxCount: 3
    enableAutoScaling: true
    availabilityZones: []
  }
  Standard : {
    vmSize: 'Standard_DS2_v2'
    count: 3
    minCount: 3
    maxCount: 5
    enableAutoScaling: true
    availabilityZones: [
      '1'
      '2'
      '3'
    ]
  }
  HighSpec : {
    vmSize: 'Standard_D4s_v3'
    count: 3
    minCount: 3
    maxCount: 5
    enableAutoScaling: true
    availabilityZones: [
      '1'
      '2'
      '3'
    ]
  }
}

var systemPoolBase = {
  name: 'npsystem'
  mode: 'System'
  osType: 'Linux'
  maxPods: 30
  type: 'VirtualMachineScaleSets'
  vnetSubnetID: !empty(subnetId) ? subnetId : json('null')
  upgradeSettings: {
    maxSurge: '33%'
  }
  nodeTaints: [
    JustUseSystemPool ? '' : 'CriticalAddonsOnly=true:NoSchedule'
  ]
}

var userPoolVmProfile = {
  vmSize: vmSize
  count: agentCount
  minCount: autoScale ? agentCount : json('null')
  maxCount: autoScale ? agentCountMax : json('null')
  enableAutoScaling: autoScale
  availabilityZones: !empty(availabilityZones) ? availabilityZones : null
}

var agentPoolProfileUser = union({
  name: 'npuser01'
  mode: 'User'
  osDiskType: osDiskType
  osDiskSizeGB: osDiskSizeGB
  osType: 'Linux'
  maxPods: maxPods
  type: 'VirtualMachineScaleSets'
  vnetSubnetID: !empty(subnetId) ? subnetId : json('null')
  upgradeSettings: {
    maxSurge: '33%'
  }
}, userPoolVmProfile)

var agentPoolProfiles = JustUseSystemPool ? array(union(systemPoolBase, userPoolVmProfile)) : concat(array(union(systemPoolBase, SystemPoolType=='Custom' && SystemPoolCustomPreset != {} ? SystemPoolCustomPreset : systemPoolPresets[SystemPoolType])), array(agentPoolProfileUser))


var aks_addons = union({
  azurepolicy: {
    config: {
      version: !empty(azurepolicy) ? 'v2' : json('null')
    }
    enabled: !empty(azurepolicy)
  }
  azureKeyvaultSecretsProvider: {
    config: {
      enableSecretRotation: 'true'
      rotationPollInterval: keyVaultAksCSIPollInterval
    }
    enabled: keyvaultEnabled
  }
  openServiceMesh: {
    enabled: openServiceMeshEnabled
    config: {}
  }
}, !(empty(workspaceId)) ? {
  omsagent: {
    enabled: !(empty(workspaceId))
    config: {
      logAnalyticsWorkspaceResourceID: !(empty(workspaceId)) ? workspaceId : json('null')
    }
  }} : {})


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

    agentPoolProfiles: agentPoolProfiles
    addonProfiles:  aks_addons

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
    aadProfile: enable_aad ? {
    managed: true
    enableAzureRBAC: enableAzureRBAC
    tenantID: aad_tenant_id
  } : null

    autoUpgradeProfile: {
      upgradeChannel: aksUpgradeChannel
    }

    autoScalerProfile: AutoscaleProfile

    apiServerAccessProfile: !empty(authorizedIPRanges) ? {
    authorizedIPRanges: authorizedIPRanges
    } : {
      enablePrivateCluster: enablePrivateCluster
      privateDNSZone: enablePrivateCluster ? aksPrivateDnsZone : ''
      enablePrivateClusterPublicFQDN: enablePrivateCluster && privateClusterDnsMethod=='none'
    }

    workloadAutoScalerProfile: {
      keda: {
          enabled: kedaEnabled
      }
    }
    oidcIssuerProfile: {
      enabled: workloadIdentityEnabled
    }
    securityProfile: {
      defender: {
        logAnalyticsWorkspaceResourceId: defenderEnabled ? workspaceId : null
        securityMonitoring: {
          enabled: defenderEnabled
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
@description('Specifies the name of the AKS cluster.')
output name string = aks.name

@description('Specifies the OIDC Issuer URL.')
output aksOidcIssuerUrl string = workloadIdentityEnabled ? aks.properties.oidcIssuerProfile.issuerURL : ''

@description('This output can be directly leveraged when creating a ManagedId Federated Identity')
output aksOidcFedIdentityProperties object = {
  issuer: workloadIdentityEnabled ? aks.properties.oidcIssuerProfile.issuerURL : ''
  audiences: ['api://AzureADTokenExchange']
  subject: 'system:serviceaccount:ns:svcaccount'
}

@description('Specifies the name of the AKS Managed Resource Group.')
output aksNodeResourceGroup string = aks.properties.nodeResourceGroup


/* _____  __       __    __  ___   ___ 
|   ____||  |     |  |  |  | \  \ /  / 
|  |__   |  |     |  |  |  |  \  V  /  
|   __|  |  |     |  |  |  |   >   <   
|  |     |  `----.|  `--'  |  /  .  \  
|__|     |_______| \______/  /__/ \__\ */


@description('Enable the Flux GitOps Operator')
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
@description('Flux Release Namespace')
output fluxReleaseNamespace string = fluxGitOpsAddon ? fluxAddon.properties.scope.cluster.releaseNamespace : ''
