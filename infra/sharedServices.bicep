targetScope = 'resourceGroup'

@description('Azure region for all shared services')
param location           string = resourceGroup().location

// Base DNS zone names
@description('Base name for the public DNS zone (e.g. contoso.com)')
param publicDnsZoneBase string = 'contoso.com'

@description('Base name for the private DNS zone (e.g. contoso.local)')
param privateDnsZoneBase string = 'contoso.local'

// Generate 4-digit random suffix
var suffixDigits = substring(uniqueString(resourceGroup().id), 0, 4)

// Unique DNS zone names with 4-digit suffix
var uniquePublicDnsZoneName = replace(publicDnsZoneBase, '.com', '-${suffixDigits}.com')
var uniquePrivateDnsZoneName = replace(privateDnsZoneBase, '.local', '-${suffixDigits}.local')

@description('Name for the Recovery Services Vault')
param vaultName          string = 'contoso-rsv'

param storageAccountPrefix string = 'staz104'
var uniqueStorageName = '${storageAccountPrefix}${uniqueString(resourceGroup().id)}'
var uniqueStorageAccountName = length(uniqueStorageName) > 24 ? substring(uniqueStorageName, 0, 24) : uniqueStorageName

@description('SKU for the Storage Account')
param storageSku         string = 'Standard_LRS'

// 1️⃣ Public DNS Zone
resource publicDnsZone 'Microsoft.Network/dnsZones@2018-05-01' = {
  name: uniquePublicDnsZoneName
  location: 'global'
}

// 2️⃣ Private DNS Zone
resource privateDnsZone 'Microsoft.Network/privateDnsZones@2020-06-01' = {
  name: uniquePrivateDnsZoneName
  location: 'global'
}

// 3️⃣ Recovery Services Vault
resource recoveryVault 'Microsoft.RecoveryServices/vaults@2021-08-01' = {
  name: vaultName
  location: location
  sku: {
    name: 'RS0'
    tier: 'Standard'
  }
  properties: {}
}

// 4️⃣ Storage Account
resource storageAccount 'Microsoft.Storage/storageAccounts@2021-08-01' = {
  name: uniqueStorageAccountName
  location: location
  sku: {
    name: storageSku
  }
  kind: 'StorageV2'
  properties: {
    accessTier: 'Hot'
    minimumTlsVersion: 'TLS1_2'
    allowBlobPublicAccess: false
    supportsHttpsTrafficOnly: true
  }
}

// Export them so other modules can consume
output publicDnsZoneName  string = uniquePublicDnsZoneName
output privateDnsZoneName string = uniquePrivateDnsZoneName
output storageAccountName string = uniqueStorageAccountName
