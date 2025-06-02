#!/usr/bin/env pwsh

# Script to deploy standalone Key Vault
# Must be run with Azure PowerShell module installed and logged in

# Parameters
$resourceGroupName = "az104-keyvault-test-rg" # Change as needed
$location = "ukSouth" # Change as needed
$adminObjectId = "3ea48438-e610-4d2e-acd0-8d95625d7b73" # Fill in the Object ID if needed

# Create resource group if it doesn't exist
$resourceGroup = Get-AzResourceGroup -Name $resourceGroupName -ErrorAction SilentlyContinue
if (-not $resourceGroup) {
    Write-Host "Creating resource group: $resourceGroupName"
    New-AzResourceGroup -Name $resourceGroupName -Location $location
}

# Get current user's Object ID if adminObjectId is not provided
if ([string]::IsNullOrEmpty($adminObjectId)) {
    Write-Host "Admin Object ID not provided, getting current user's Object ID..."
    $currentUser = Get-AzADUser -SignedIn
    $adminObjectId = $currentUser.Id
    Write-Host "Using Object ID: $adminObjectId"
}

# Deploy the standalone Key Vault
Write-Host "Deploying standalone Key Vault..."
$deploymentName = "deploy-keyvault-$(Get-Date -Format 'yyyyMMddHHmmss')"

New-AzResourceGroupDeployment `
    -Name $deploymentName `
    -ResourceGroupName $resourceGroupName `
    -TemplateFile ".\keyvault-standalone.bicep" `
    -adminObjectId $adminObjectId

Write-Host "Deployment complete!"
