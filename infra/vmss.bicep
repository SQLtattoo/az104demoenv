targetScope = 'resourceGroup'

@description('Location for all resources')
param location string = resourceGroup().location

@description('Name of the Virtual Network')
param vnetName string = 'spoke2-vnet'

@description('Name of the subnet to deploy VMSS into')
param subnetName string = 'default'

@description('VM SKU for the scale set')
param vmSku string = 'Standard_B2s'

@description('Number of VM instances')
param instanceCount int = 2

@description('Admin username for VM')
param adminUsername string = 'azureuser'

@secure()
@description('Admin password for VM')
param adminPassword string

// Reference existing VNet and Subnet
resource vnet 'Microsoft.Network/virtualNetworks@2021-05-01' existing = {
  name: vnetName
}

var subnetId = '${vnet.id}/subnets/${subnetName}'

@description('Name of the VM Scale Set')
var vmssName = 'vmssaz104'

// VM Scale Set resource
resource vmss 'Microsoft.Compute/virtualMachineScaleSets@2021-07-01' = {
  name: vmssName
  location: location
  sku: {
    name: vmSku
    tier: 'Standard'
    capacity: instanceCount
  }
  properties: {
    // required for flexible orchestration
    platformFaultDomainCount: 1
    orchestrationMode: 'Flexible'
    upgradePolicy: {
      mode: 'Manual'
    }
    virtualMachineProfile: {
      storageProfile: {
        imageReference: {
        publisher: 'MicrosoftWindowsServer'
        offer: 'WindowsServer'
        sku: '2019-Datacenter'
        version: 'latest'
      }
      osDisk: {
        createOption: 'FromImage'
        managedDisk: {
          storageAccountType: 'Premium_LRS'
        }
      }
      }
      osProfile: {
        computerNamePrefix: vmssName
        adminUsername: adminUsername
        adminPassword: adminPassword
      }
      networkProfile: {
        networkApiVersion: '2021-05-01'  // Add this line at the networkProfile level
        networkInterfaceConfigurations: [
          {
            name: 'nicconfig'
            properties: {
              primary: true
              ipConfigurations: [
                {
                  name: 'ipconfig'
                  properties: {
                    subnet: {
                      id: subnetId
                    }
                  }
                }
              ]
            }
          }
        ]
      }
    }
  }
}

// User-assigned identity for deployment script
resource scriptIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2018-11-30' = {
  name: '${vmssName}-scriptIdentity'
  location: location
}

// Role assignment to allow the managed identity to deallocate VMSS
resource roleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(resourceGroup().id, scriptIdentity.id, 'Contributor')
  scope: resourceGroup()
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'b24988ac-6180-42a0-ab88-20f7382dd24c') // Contributor role
    principalId: scriptIdentity.properties.principalId
    principalType: 'ServicePrincipal'
  }
}

// Deallocate VMSS instances to avoid charges (runs Azure CLI during deployment)
resource deallocateVmssScript 'Microsoft.Resources/deploymentScripts@2019-10-01-preview' = {
  name: 'deallocate-${vmssName}'
  location: location
  kind: 'AzureCLI'
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${scriptIdentity.id}': {}
    }
  }
  properties: {
    azCliVersion: '2.45.0'  // Updated to a newer version
    scriptContent: 'az vmss deallocate --resource-group ${resourceGroup().name} --name ${vmssName}'
    retentionInterval: 'PT1H'
    forceUpdateTag: uniqueString(deployment().name)
  }
  dependsOn: [
    vmss
    roleAssignment  // Wait for role assignment to be created
  ]
}
