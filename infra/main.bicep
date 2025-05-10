targetScope = 'resourceGroup'

@description('Location for hub vnet resources')
param location1 string = 'ukSouth'

@description('Location for spoke1 vnet resources')
param location2 string = 'ukSouth'

@description('Location for spoke2 vnet resources')
param location3 string = 'northeurope'

@description('Location for workload vnet resources')
param location4 string = 'eastus2'

@description('Administrator username for virtual machines')
param adminUsername string

@description('Administrator password for virtual machines')
@secure()
param adminPassword string

// 1️⃣ The hub & spokes
module network 'network.bicep' = {
  name: 'vnets'
  params: {
    hublocation: location1
    spoke1location: location2
    spoke2location: location3
    workloadlocation: location4
    hubVnetName: 'hub-vnet'
    spoke1VnetName: 'spoke1-vnet'
    spoke2VnetName: 'spoke2-vnet'
    workloadVnetName: 'workload-vnet'
  }
}

module bastion 'bastion.bicep' = {
  name: 'bastion'
  params: {
    location:      location1
    vnetName:      'hub-vnet'
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
    location:       location1     // your hubLocation param
    vnetName:       'hub-vnet'
    gatewayPip:     'hub-vpn-pip'       // or parameterize from azure.yaml
    vpnGatewayName: 'hub-vpn-gateway'   // likewise
  }
  dependsOn: [
    bastion       // ensure Bastion/subnets exist first, if you like
  ]
} 

// 4️⃣ Enable VPN transit on the existing peerings
module enableGatewayTransit 'enableGatewayTransit.bicep' = {
  name: 'enableGatewayTransit'
  params: {
    hubVnetName:    'hub-vnet'
    spoke1VnetName: 'spoke1-vnet'
    spoke2VnetName: 'spoke2-vnet'
  }
  dependsOn: [
    vpnGateway         // the module name for your VPN gateway in main.bicep
  ]
} 

module webTier 'webTier.bicep' = {
  name: 'webTier'
  params: {
    location:       location1
    vnetName:       'spoke1-vnet'
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
    //enableGatewayTransit
  ]
}

// Deploy App Tier in spoke2
module appTier 'appTier.bicep' = {
  name: 'appTier'
  params: {
    location: location3  // North Europe region
    vnetName: 'spoke2-vnet'
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

// Deploy Workload Tier in East US
module workloadTier 'workloadTier.bicep' = {
  name: 'workloadTier'
  params: {
    location: location4  // East US region
    vnetName: 'workload-vnet'
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
    location:           location3
    vnetName:           'spoke2-vnet'
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
    location:            location1
    publicDnsZoneBase:   publicDnsZoneBase
    privateDnsZoneBase:  privateDnsZoneBase
    vaultName:           vaultName
    storageAccountPrefix:  storageAccountPrefix
  }
  dependsOn: [
    workloadTier
  ]
}
