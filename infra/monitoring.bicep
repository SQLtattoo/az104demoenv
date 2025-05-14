targetScope = 'resourceGroup'

@description('Region for your monitoring resources')
param location       string

@description('Name for the Log Analytics Workspace')
param lawName        string = 'az104-law'

@description('Retention in days for logs/metrics')
param retentionDays  int    = 30

@description('Name of the Storage Account to monitor')
param storageAccountName string

@description('Name of the Application Gateway to monitor')
param appGwName string = 'app-gateway'

// 1️⃣ Log Analytics workspace
resource law 'Microsoft.OperationalInsights/workspaces@2021-06-01' = {
  name: lawName
  location: location
  properties: {
    sku: {
      name: 'PerGB2018'
    }
    retentionInDays: retentionDays
  }
}

// Helper to build diagnostic settings
var diagSettingsName = 'diagToLAW'

// Declare existing resources for diagnostic scopes
resource vpnGateway 'Microsoft.Network/virtualNetworkGateways@2021-05-01-preview' existing = {
  name: 'hub-vpn-gateway'
}
resource appGw 'Microsoft.Network/applicationGateways@2021-05-01-preview' existing = {
  name: appGwName
}
resource lb 'Microsoft.Network/loadBalancers@2021-05-01-preview' existing = {
  name: 'web-lb'
}
resource bastion 'Microsoft.Network/bastionHosts@2021-05-01-preview' existing = {
  name: 'hub-bastion'
}
resource storageAccount 'Microsoft.Storage/storageAccounts@2021-06-01' existing = {
  name: storageAccountName
}

// 2️⃣ Diagnostic settings for VPN Gateway
resource vpnDiag 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: diagSettingsName
  scope: vpnGateway
  properties: {
    workspaceId: law.id
    logs: [
      { category: 'GatewayDiagnosticLog' , enabled: true }
      { category: 'TunnelDiagnosticLog'  , enabled: true }
    ]
    metrics: [
      { category: 'AllMetrics', enabled: true, retentionPolicy: { days: retentionDays, enabled: false } }
    ]
  }
}

// 3️⃣ Diagnostic settings for Application Gateway
resource appGwDiag 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: diagSettingsName
  scope: appGw
  properties: {
    workspaceId: law.id
    logs: [
      { category: 'ApplicationGatewayAccessLog'      , enabled: true }
      { category: 'ApplicationGatewayFirewallLog'    , enabled: true }
      { category: 'ApplicationGatewayPerformanceLog' , enabled: true }
    ]
    metrics: [
      { category: 'AllMetrics', enabled: true, retentionPolicy: { days: retentionDays, enabled: false } }
    ]
  }
}

// 4️⃣ Diagnostic settings for Public Load Balancer (Web tier)
resource lbDiag 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: diagSettingsName
  scope: lb
  properties: {
    workspaceId: law.id
    // logs removed due to unsupported categories
    metrics: [
      { category: 'AllMetrics', enabled: true, retentionPolicy: { days: retentionDays, enabled: false } }
    ]
  }
}

// 5️⃣ Diagnostic settings for Azure Bastion
resource bastionDiag 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: diagSettingsName
  scope: bastion
  properties: {
    workspaceId: law.id
    logs: [
      { category: 'BastionAuditLogs' , enabled: true }
    ]
  }
}

// 6️⃣ Diagnostic settings for Storage Account
resource storageDiag 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: diagSettingsName
  scope: storageAccount
  properties: {
    workspaceId: law.id
    // Storage logs categories unsupported; use metrics only or use az to list valid categories
    metrics: [
      { category: 'Transaction', enabled: true, retentionPolicy: { days: retentionDays, enabled: false } }
    ]
  }
}
