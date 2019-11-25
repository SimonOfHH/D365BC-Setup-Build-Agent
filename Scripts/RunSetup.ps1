Clear-Host

#Requires -RunAsAdministrator

$ScriptDirectory = Split-Path -Path $MyInvocation.MyCommand.Definition -Parent
. ("$ScriptDirectory\Parameters\Parameters.ps1")
. ("$ScriptDirectory\Initialize-Dependencies.ps1")
. ("$ScriptDirectory\New-CustomAzResourceGroup.ps1")
. ("$ScriptDirectory\New-CustomAgentPool.ps1")
. ("$ScriptDirectory\New-CustomAzVM.ps1")
. ("$ScriptDirectory\New-RunAsServicePrincipal.ps1")
. ("$ScriptDirectory\New-CustomExtension.ps1")
. ("$ScriptDirectory\New-CustomAzStorageTable.ps1")
. ("$ScriptDirectory\Set-CustomVariableGroup.ps1")
. ("$ScriptDirectory\Get-CustomVariableGroup.ps1")
. ("$ScriptDirectory\Get-VariableBodyFromObject.ps1")

# ==============================================
# Update "Parameters.ps1 before you start"
# Run as Administrator (to be able to load dependencies)
# Attention: you'll need to have at least "User Access Administrator"-permissions in the used Azure Subscription, otherwise you're not able to create Automation Accounts
# ==============================================

# This script does the following steps:
#   [Azure]  Connect with your Azure subscription
#   [Azure]  Create a new Resource Group (if not existing)
#   [DevOps] Create Variable Group/Library in DevOps-project to save necessary variables
#   [DevOps] Create Agent Pool in DevOps-organization
#   [DevOps] Install ALOps-Extension in DevOps-organization (if not existing)
#   [Azure]  Create Agent VM (by default based on the template from Freddy under: https://raw.githubusercontent.com/microsoft/nav-arm-templates/master/buildagent.json)
#   [Azure]  Create a new Azure Storage Table in the existing Storage Account (with initial entry in it)
#              This is used to save Power on/off commands for the VM later
#   [DevOps] Update Variable Group/Library in DevOps-project
#   [Azure]  Create Automation Account
#   [Azure]  Create Runbook for Automation Account and import "Runbook-Template" to it
#   [Azure]  Create Webhook for the Runbook to be able to execute it from the [DevOps]-pipeline
#   [Azure]  Create Schedule for the Runbook to be able to handle delayed Shutdown of VM
#

#
# When everything is done you'll need to add "ALOps-Pipeline.yaml" from the "Templates"-folder to your projects repository
# Also you'll need to go to "Pipelines" --> "Library" --> "CI ALOps" and select "Allow access to all pipelines"
# Then you create a Build-Pipeline in your Project where you select the template from above
# Check if any modifications are necessary and go for it!
#

Initialize-Dependencies

Write-Host "Checking for active Azure Connection..."
$connected = (Get-AzContext).Subscription.Name -eq $subscriptionName
if (-not($connected)) {    
    try {
        Write-Host "Selecting correct subscription..."
        $context = Get-AzSubscription -SubscriptionName $subscriptionName
        Set-AzContext $context | Out-Null
    }
    catch {
        Write-Host "Please login first to select the correct subscription"
        Connect-AzAccount -Force | Out-Null
        $context = Get-AzSubscription -SubscriptionName $subscriptionName
        Set-AzContext $context | Out-Null
    }
}
Write-Host "Connected"

$variableGroupParams = @{
    GroupName          = "CI ALOps"
    DevOpsOrganisation = $devOpsOrganisation 
    DevOpsProject      = $devOpsProject 
    VstsToken          = $vstsToken
}

# 1. Create Resource Group
New-CustomAzResourceGroup -ResourceGroupName $resourceGroupName -ResourceLocation $resourceLocation -CreateIfNotExisting $true | Out-Null
Set-CustomVariableGroup -Variables ([pscustomobject]@{Name = "BuildAgentResourceGroupName"; Value = $resourceGroupName; IsSecret = $false }) @variableGroupParams | Out-Null
# 2. Create Agent Pool
New-CustomAgentPool -PoolName $poolName -DevOpsOrganisation $devOpsOrganisationUri -VstsToken $vstsToken | Out-Null
Set-CustomVariableGroup -Variables ([pscustomobject]@{Name = "BuildAgentPoolName"; Value = $poolName; IsSecret = $false }) @variableGroupParams | Out-Null
# 3. Install ALOps Extension in DevOps-Organisation
New-CustomExtension -DevOpsOrganisation $devOpsOrganisation -VstsToken $vstsToken
# 4. Create VM
$params = @{
    ResourceGroupName  = $resourceGroupName
    VMName             = $vmName        
    VmAdminUser        = $vmAdminUser
    VmAdminPass        = $vmadminPass        
    DevOpsOrganisation = $devOpsOrganisationUri
    PoolName           = $poolName
    VstsToken          = $vstsToken
    SetupScript        = $finalSetupScriptUrl
}
New-CustomAzVM @params
Set-CustomVariableGroup -Variables ([pscustomobject]@{Name = "BuildAgentVM01Name"; Value = $vmName; IsSecret = $false }) @variableGroupParams | Out-Null

# 5. Create Storage Table that holds the Shutdown/Startup-commands (we'll use the already existing storage account that was created during VM creation)
# This check here is to avoid problems, when running the script multiple times
# It checks if there is already a variable for the SAS Token in the library
$variables = Get-CustomVariableGroup @variableGroupParams
if ($variables) {
    if ($variables.StorageAccountTableToken) {
        $sasToken = $variables.StorageAccountTableToken
    }
}

$storageAccount = Get-AzStorageAccount -ResourceGroupName $resourceGroupName | Select-Object -First 1
if (-not($sasToken)) {
    $storageAccountTable = Get-AzStorageTable -Name "PowerManagement" -Context $storageAccount.Context -ErrorAction SilentlyContinue
    if (-not($storageAccountTable)) {
        New-CustomAzStorageTable -Context $storageAccount.Context -TableName "PowerManagement" | Out-Null
        # Add entry to table if the table was just created
        $uri = "$($storageAccount.Context.TableEndPoint)PowerManagement(PartitionKey='$($resourceGroupName)', RowKey='$($vmName)')$sasToken"
        $params = @{
            "Command"      = ""
            "PartitionKey" = $resourceGroupName
            "RowKey"       = $vmName
        }        
        Invoke-RestMethod -Method Put -Uri $uri -Headers @{'Accept' = 'application/json'; 'content-type' = 'application/json' } -Body ($params | ConvertTo-Json -Compress) -UseBasicParsing
    }
    $sasToken = New-AzStorageAccountSASToken -Service Table -ResourceType Service, Container, Object -Permission "racwdlup" -Context $storageAccount.Context -ExpiryTime (Get-Date).AddYears(10) # Token expires after 10 years
}
Set-CustomVariableGroup -Variables ([pscustomobject]@{Name = "StorageAccountTableEndpoint"; Value = $storageAccount.Context.TableEndPoint; IsSecret = $false }) @variableGroupParams | Out-Null
# Avoid updating if it was already existing, since it might was set to "Secret"
if (-not($variables.StorageAccountTableToken)) {
    Set-CustomVariableGroup -Variables ([pscustomobject]@{Name = "StorageAccountTableToken"; Value = $sasToken; IsSecret = $false }) @variableGroupParams | Out-Null
}

# 6. Create Automation Account (needs more than "Contributor"-permissions to have RunAs-Connections)
if (-not(Get-AzAutomationAccount -ResourceGroupName $resourceGroupName -Name $automationAccountName -ErrorAction SilentlyContinue)) {
    Write-Host "Creating Automation Account..."
    New-AzAutomationAccount -ResourceGroupName $resourceGroupName -Location $resourceLocation -Name $automationAccountName -Plan Basic | Out-Null
    Write-Host "Setting up auth-connection for Automation Account..."
    $FieldValues = @{"AutomationCertificateName" = "BuildAgentConnectionCertificate"; "SubscriptionID" = (Get-AzContext).Subscription.Id }    
    New-RunAsServicePrincipal -rgName $resourceGroupName -AutomationAccountName $automationAccountName -ApplicationDisplayName "$automationAccountName-App" -SubscriptionId (Get-AzContext).Subscription.Id -SelfSignedCertPlainPassword "Test132456" -SelfSignedCertNoOfMonthsUntilExpired 120 | Out-Null
}

# 7. Create RunBook
if (-not(Get-AzAutomationRunbook -ResourceGroupName $resourceGroupName -Name $automationRunbookName -AutomationAccountName $automationAccountName -ErrorAction SilentlyContinue)) {    
    Write-Host "Creating Runbook based on Template-Script..."
    Import-AzAutomationRunbook -ResourceGroupName $resourceGroupName -Name $automationRunbookName -AutomationAccountName $automationAccountName -Path "Templates\Runbook-Template.ps1" -Type PowerShell -Force | Out-Null
    Write-Host "Publishing Runbook..."
    Publish-AzAutomationRunbook -ResourceGroupName $resourceGroupName -AutomationAccountName $automationAccountName -Name $automationRunbookName | Out-Null
}

# 8. Create Webhook
$webhook = Get-AzAutomationWebhook -Name "InvokeRunbook" -ResourceGroupName $resourceGroupName -AutomationAccountName $automationAccountName -ErrorAction SilentlyContinue
if (-not($webhook)) {
    Write-Host "Creating Webhook..."
    $Webhook = New-AzAutomationWebhook -Name "InvokeRunbook" -IsEnabled $True -ExpiryTime (Get-Date).AddYears(9) -RunbookName $automationRunbookName -ResourceGroup $resourceGroupName -AutomationAccountName $automationAccountName -Force
    Set-CustomVariableGroup -Variables ([pscustomobject]@{Name = "PowerManagementWebhookURI"; Value = $Webhook.WebhookURI; IsSecret = $false }) @variableGroupParams | Out-Null
}

# 9. Create Schedule
$schedule = Get-AzAutomationSchedule -AutomationAccountName $automationAccountName -ResourceGroupName $resourceGroupName -Name $automationRunbookScheduleName -ErrorAction SilentlyContinue
if (-not($schedule)) {
    Write-Host "Creating Schedule..."
    $StartTime = (Get-Date).AddMinutes(6)
    $schedule = New-AzAutomationSchedule -AutomationAccountName $automationAccountName -ResourceGroupName $resourceGroupName -Name $automationRunbookScheduleName -StartTime $StartTime -HourInterval 1
    Write-Host "Registering Schedule..."
    # These are the parameters for the scheduler
    $params = @{
        "Name"          = $vmName
        "ResourceGroup" = $resourceGroupName
        "TableURI"      = $storageAccount.Context.TableEndPoint
        "SASToken"      = $sasToken
    }
    $scheduleParameters = @{WebhookName = "InvokeRunbook"; RequestBody = ($params | ConvertTo-Json) } 
    Register-AzAutomationScheduledRunbook -AutomationAccountName $automationAccountName -RunbookName $automationRunbookName -ScheduleName $automationRunbookScheduleName -ResourceGroupName $resourceGroupName -Parameters @{webhookData = $scheduleParameters } | Out-Null
}