targetScope = 'resourceGroup'

@description('Location for hub vnet resources')
param hubLocation string = 'ukSouth'

@description('Location for spoke1 vnet resources')
param spoke1Location string = 'ukSouth'

@description('Location for spoke2 vnet resources')
param spoke2Location string = 'northeurope'

@description('Location for workload vnet resources')
param workloadLocation string = 'eastus2'

@description('Administrator username for virtual machines')
param adminUsername string

@description('Administrator password for virtual machines')
@secure()
param adminPassword string

var hubVnetName = 'hub-vnet'
var spoke1VnetName = 'spoke1-vnet'
var spoke2VnetName = 'spoke2-vnet'
var workloadVnetName = 'workload-vnet'

// 1️⃣ The hub & spokes
module network 'network.bicep' = {
  name: 'vnets'
  params: {
    hublocation: hubLocation
    spoke1location: spoke1Location
    spoke2location: spoke2Location
    workloadlocation: workloadLocation
    hubVnetName: hubVnetName
    spoke1VnetName: spoke1VnetName
    spoke2VnetName: spoke2VnetName
    workloadVnetName: workloadVnetName
  }
}

module bastion 'bastion.bicep' = {
  name: 'bastion'
  params: {
    location:      hubLocation
    vnetName:      hubVnetName
    bastionName:   'hub-bastion'
    pipName:       'hub-bastion-pip'
  }
  dependsOn: [
    network  // ensure the VNet & subnet exist
  ]
}

// 3️⃣ VPN Gateway in the hub VNet
module vpnGateway 'vpnGateway.bicep' = {
  name: 'vpn'
  params: {
    location:       hubLocation     // your hubLocation param
    vnetName:       hubVnetName
    gatewayPip:     'hub-vpn-pip'       // or parameterize from azure.yaml
    vpnGatewayName: 'hub-vpn-gateway'   // likewise
  }
  dependsOn: [
    network       // ensure the VNet & subnet exist
  ]
} 

// 4️⃣ Enable VPN transit on the existing peerings
module enableGatewayTransit 'enableGatewayTransit.bicep' = {
  name: 'enableGatewayTransit'
  params: {
    hubVnetName:    hubVnetName
    spoke1VnetName: spoke1VnetName
    spoke2VnetName: spoke2VnetName
  }
  dependsOn: [
    vpnGateway         // the module name for your VPN gateway in main.bicep
  ]
} 

module webTier 'webTier.bicep' = {
  name: 'webTier'
  params: {
    location:       hubLocation
    vnetName:       spoke1VnetName
    lbName:         'web-lb'
    vmNames:        [
      'web1-vm'
      'web2-vm'
    ]
    subnetName:     'default'
    adminUsername:  adminUsername
    adminPassword:  adminPassword
  }
  dependsOn: [
    network // Depends on network module that creates the spoke1-vnet
  ]
}

// Deploy App Tier in spoke2
module appTier 'appTier.bicep' = {
  name: 'appTier'
  params: {
    location: spoke2Location  // North Europe region
    vnetName: spoke2VnetName
    appGwName: 'app-gateway'
    vmNames: [
      'vm1'
    ]
    vmSubnetName: 'default'
    appGwSubnetName: 'AppGwSubnet' // Make sure this subnet exists in the spoke2-vnet
    adminUsername: adminUsername
    adminPassword: adminPassword
  }
  dependsOn: [
    network  // Depends on network module that creates the spoke2-vnet
  ]
}

// Deploy Workload Tier 
module workloadTier 'workloadTier.bicep' = {
  name: 'workloadTier'
  params: {
    location: workloadLocation  // East US region
    vnetName: workloadVnetName
    lbName: 'workload-lb'
    vmName: 'workload1-vm'
    subnetName: 'default'
    adminUsername: adminUsername
    adminPassword: adminPassword
  }
  dependsOn: [
    network  // Depends on network module that creates the workload-vnet
  ]
}

module consumerPe 'consumerPE.bicep' = {
  name: 'consumerPE'
  params: {
    location:           spoke2Location
    vnetName:           spoke2VnetName
    consumerSubnetName: 'default'
    peName:             'workload-pe'
    plsName:            'workload-pls'
  }
  dependsOn: [
    workloadTier
  ]
}


// Shared services parameters
param publicDnsZoneBase  string = 'contoso.com'
param privateDnsZoneBase string = 'contoso.local'
param vaultName          string = 'contoso-rsv'
param storageAccountPrefix string = 'staz104'

// Deploy shared services
module shared 'sharedServices.bicep' = {
  name: 'sharedServices'
  params: {
    location:            hubLocation
    publicDnsZoneBase:   publicDnsZoneBase
    privateDnsZoneBase:  privateDnsZoneBase
    vaultName:           vaultName
    storageAccountPrefix:  storageAccountPrefix
  }
  dependsOn: [
    workloadTier
  ]
}

module dnsLinks 'dnsLinks.bicep' = {
  name: 'dnsLinks'
  params: {
    privateDnsZoneName:   shared.outputs.privateDnsZoneName
    hubVnetName:          hubVnetName
    spoke1VnetName:       spoke1VnetName
    spoke2VnetName:       spoke2VnetName
  }
  dependsOn: [
    shared 
  ]
}

module monitoring 'monitoring.bicep' = {
  name: 'monitoring'
  params: {
    location:      hubLocation
    lawName:       'az104-law'
    retentionDays: 30
    storageAccountName: shared.outputs.storageAccountName  // add this param if needed for storageDiag
  }
  dependsOn: [
    // ensure all your resources exist first
    shared
    network
    bastion
    vpnGateway
    enableGatewayTransit
    webTier
    appTier
    workloadTier
    dnsLinks
  ]
}
