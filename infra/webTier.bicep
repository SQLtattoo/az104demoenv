// infra/webTier.bicep
targetScope = 'resourceGroup'

@description('Region for Web tier')
param location    string

@description('Name of the spoke1 VNet')
param vnetName    string

@description('Name for the Public Load Balancer')
param lbName      string = 'web-lb'

@description('List of VM names to create behind the LB')
param vmNames     array = [
  'web1-vm'
  'web2-vm'
]

@description('Subnet name to use for VMs and LB')
param subnetName  string = 'default'

@secure()
param adminPassword string

@description('Admin username for the VMs')
param adminUsername string

// 1️⃣ Reference the spoke VNet
resource spoke1Vnet 'Microsoft.Network/virtualNetworks@2021-05-01' existing = {
  name: vnetName
}

// 2️⃣ Create a public IP for the LB
resource lbPIP 'Microsoft.Network/publicIPAddresses@2021-02-01' = {
  name: '${lbName}-pip'
  location: location
  sku: { name: 'Standard' }
  properties: {
    publicIPAllocationMethod: 'Static'
  }
}

// 3️⃣ Deploy the Load Balancer
var frontendIPConfigId = resourceId('Microsoft.Network/loadBalancers/frontendIPConfigurations', lbName, 'LoadBalancerFrontEnd')
var backendPoolId = resourceId('Microsoft.Network/loadBalancers/backendAddressPools', lbName, 'WebPool')
var healthProbeId = resourceId('Microsoft.Network/loadBalancers/probes', lbName, 'healthProbe')

resource lb 'Microsoft.Network/loadBalancers@2021-05-01' = {
  name: lbName
  location: location
  sku: { name: 'Standard' }
  properties: {
    frontendIPConfigurations: [
      {
        name: 'LoadBalancerFrontEnd'
        properties: {
          publicIPAddress: { id: lbPIP.id }
        }
      }
    ]
    backendAddressPools: [
      {
        name: 'WebPool'
      }
    ]
    loadBalancingRules: [
      {
        name: 'HttpRule'
        properties: {
          frontendIPConfiguration: { id: frontendIPConfigId }
          backendAddressPool:      { id: backendPoolId }
          protocol:                'Tcp'
          frontendPort:            80
          backendPort:             80
          enableFloatingIP:        false
          idleTimeoutInMinutes:    4
          probe: { id: healthProbeId }
        }
      }
    ]
    probes: [
      {
        name: 'healthProbe'
        properties: {
          protocol:          'Http'
          port:              80
          requestPath:       '/'
          intervalInSeconds: 5
          numberOfProbes:    2
        }
      }
    ]
    inboundNatRules: [
      {
        name: 'RDP-VM1'
        properties: {
          frontendIPConfiguration: { id: frontendIPConfigId }
          protocol: 'Tcp'
          frontendPort: 33891
          backendPort: 3389
          idleTimeoutInMinutes: 4
          enableFloatingIP: false
        }
      }, {
        name: 'RDP-VM2'
        properties: {
          frontendIPConfiguration: { id: frontendIPConfigId }
          protocol: 'Tcp'
          frontendPort: 33892
          backendPort: 3389
          idleTimeoutInMinutes: 4
          enableFloatingIP: false
        }
      }
    ]
  }
  dependsOn: [
    nics // Ensure NICs are created before referencing them
  ]
}

// 4️⃣ Create NICs + VMs and attach to LB
var subnetRef = '${spoke1Vnet.id}/subnets/${subnetName}' // Corrected subnet reference

// Define NICs first
resource nics 'Microsoft.Network/networkInterfaces@2021-02-01' = [for (vm, i) in vmNames: {
  name: '${vm}-nic'
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          subnet: { id: subnetRef }
          privateIPAllocationMethod: 'Dynamic'
          loadBalancerBackendAddressPools: [
            { id: backendPoolId } // Use variable for Load Balancer reference
          ]
          loadBalancerInboundNatRules: [
            { id: resourceId('Microsoft.Network/loadBalancers/inboundNatRules', lbName, 'RDP-VM${i + 1}') }
          ]
        }
      }
    ]
  }
}]

// Then define VMs with explicit dependencies
resource vms 'Microsoft.Compute/virtualMachines@2021-07-01' = [for (vm, i) in vmNames: {
  name: vm
  location: location
  properties: {
    hardwareProfile: { vmSize: 'Standard_B4ms' }
    networkProfile: {
      networkInterfaces: [
        {
          id: nics[i].id // Reference the NIC directly
        }
      ]
    }
    storageProfile: {
      imageReference: {
        publisher: 'MicrosoftWindowsServer'
        offer:     'WindowsServer'
        sku:       '2019-Datacenter'
        version:   'latest'
      }
      osDisk: {
        createOption: 'FromImage'
      }
    }
    osProfile: {
      computerName: vm
      adminUsername: adminUsername 
      adminPassword: adminPassword
    }
  }
  dependsOn: [
    nics[i] // Explicit dependencies
  ]
}]
