# AZ-104 Azure Administrator Demo Environment

This repository contains infrastructure as code (Bicep) to deploy a comprehensive environment for Azure Administrator (AZ-104) training and demonstrations.

## Pre-deployment Steps

1. **Find your Object ID**:
   Before deploying, you must add your Azure AD Object ID to the `azure.yaml` file:
   
   ```bash
   az ad signed-in-user show --query id -o tsv
   ```
   
   Copy the output and paste it as the value for `adminObjectId` in `azure.yaml`.

2. **Verify subscription access**:
   - Ensure you have Owner or Contributor access to the subscription
   - For governance components, you need User Access Administrator to create custom roles

## Deployment Instructions

1. **Deploy the environment**:
   ```bash
   azd up
   ```
   
2. **If monitoring deployment fails**:
   It's expected that monitoring may fail on the first deployment because VMs aren't ready yet.
   Run a second deployment after VMs are fully provisioned:
   ```bash
   azd provision
   ```

## Troubleshooting

- **Key Vault deployment fails**: Verify your Object ID is correct and that you have sufficient permissions
- **Custom RBAC role not visible**: It may take a few minutes for the role to appear in the Azure Portal
- **Monitoring agent failures**: Ensure VMs are fully provisioned before deploying monitoring

## Demo Features

- Hub and spoke network topology
- Application Gateway and Load Balancer configurations
- Private Link and Private Endpoints
- Azure Bastion for secure VM access
- Key Vault and Customer-Managed Keys
- Custom RBAC roles and Policy definitions

