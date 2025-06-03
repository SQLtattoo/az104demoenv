# Set variables
$resourceGroupName = "az104demos-rg"
$vaultName = "contoso-rsv"
$location = "uksouth"  # e.g., "East US"

# Get the Recovery Services Vault
$vault = Get-AzRecoveryServicesVault -Name $vaultName -ResourceGroupName $resourceGroupName

# Set the vault context
Set-AzRecoveryServicesVaultContext -Vault $vault

# Disable soft delete (if not always-on)
$properties = Get-AzRecoveryServicesVaultProperty -VaultId $vault.ID

if ($properties.SoftDeleteFeatureState -eq "Enabled") {
    Write-Host "Disabling soft delete..."
    Disable-AzRecoveryServicesSoftDelete -VaultId $vault.ID -Force
    Write-Host "Soft delete has been disabled."
} elseif ($properties.SoftDeleteFeatureState -eq "AlwaysON") {
    Write-Host "Soft delete is Always-on and cannot be disabled."
} else {
    Write-Host "Soft delete is already disabled."
}