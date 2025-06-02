# Script to tear down and redeploy the AZ104 environment

# Step 1: Navigate to the project directory
cd c:\MyDemos\AZD\az104

# Step 2: Tear down the current environment
Write-Host "Tearing down the current environment..." -ForegroundColor Yellow
azd down --purge --force

# Step 3: Redeploy the environment
Write-Host "Redeploying the environment..." -ForegroundColor Green
azd up
