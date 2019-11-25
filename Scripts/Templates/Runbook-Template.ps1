Param(
    [object]$WebhookData
)

function Get-DefaultHeaders {
    $headers = @{'Accept' = 'application/json'; 'content-type' = 'application/json' }
    $headers
}
function Get-StorageUri {
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $ResourceGroupName,
        [Parameter(Mandatory = $true)]
        [string]
        $VmName,
        [Parameter(Mandatory = $true)]
        [string]
        $StorageAccountUri,
        [Parameter(Mandatory = $true)]
        [string]
        $SharedAccessSignature
    )
    $uri = "$($StorageAccountUri)PowerManagement(PartitionKey='$ResourceGroupName', RowKey='$VmName')$SharedAccessSignature"
    $uri
}
function Update-CommandInTable {
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $ResourceGroupName,
        [Parameter(Mandatory = $true)]
        [string]
        $VmName,
        [Parameter(Mandatory = $true)]
        [string]
        $StorageAccountUri,
        [Parameter(Mandatory = $true)]
        [string]
        $SharedAccessSignature,
        [Parameter(Mandatory = $false)]
        [string]
        $Command
    )
    if (-not($Command)) {
        $Command = ""
    }    
    $uri = Get-StorageUri -ResourceGroupName $ResourceGroupName -VmName $VmName -StorageAccountUri $StorageAccountUri -SharedAccessSignature $SharedAccessSignature
    $params = @{
        "Command"      = $Command
        "PartitionKey" = $ResourceGroupName
        "RowKey"       = $VmName
    }
    Invoke-RestMethod -Method Put -Uri $uri -Headers (Get-DefaultHeaders) -Body ($params | ConvertTo-Json -Compress) -UseBasicParsing | Out-Null
}
function Get-CurrentTableValues {
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $ResourceGroupName,
        [Parameter(Mandatory = $true)]
        [string]
        $VmName,
        [Parameter(Mandatory = $true)]
        [string]
        $StorageAccountUri,
        [Parameter(Mandatory = $true)]
        [string]
        $SharedAccessSignature
    )
    if (-not($Command)) {
        $Command = ""
    }
    $uri = Get-StorageUri -ResourceGroupName $ResourceGroupName -VmName $VmName -StorageAccountUri $StorageAccountUri -SharedAccessSignature $SharedAccessSignature    
    $webRequest = Invoke-WebRequest -Uri $uri -Method Get -Headers @{'Accept' = 'application/json'; 'content-type' = 'application/json' } -UseBasicParsing
    $currentValues = $webRequest.Content | ConvertFrom-Json
    $currentValues
}

if (-not($WebhookData.RequestBody)) {
    $WebhookData = (ConvertFrom-Json -InputObject $WebhookData)
}

$values = ConvertFrom-Json -InputObject $WebhookData.RequestBody

# The storage account table is in the following format
# ResourceGroupName | VM Name | Command     | Timestamp
# TEST-RG           | TESTVM1 | Shutdown    | 2019-11-19T14:54:14.833Z

$Command = $values.Command
$VmName = $values.Name
$ResourceGroupName = $values.ResourceGroup
$StorageAccountUri = $values.TableURI
$SharedAccessSignature = $values.SASToken

# TODO: Remove before using in production, only for debugging
Write-Output "Parameter:"
Write-Output "  ResourceGroupName: $ResourceGroupName"
Write-Output "  VMName: $VMName"
Write-Output "  Command: $Command"
Write-Output "  StorageAccountUri: $StorageAccountUri"
Write-Output "  SharedAccessSignature: $SharedAccessSignature"

if ($Command) {
    $currentValues = Get-CurrentTableValues -ResourceGroupName $ResourceGroupName -VmName $VmName -StorageAccountUri $StorageAccountUri -SharedAccessSignature $SharedAccessSignature        
    # Only update if Command is different, to avoid updating timestamp
    if ($currentValues.Command -ne $Command) {
        Update-CommandInTable -ResourceGroupName $ResourceGroupName -VmName $VmName -StorageAccountUri $StorageAccountUri -SharedAccessSignature $SharedAccessSignature -Command $Command
    }
}

$connectionName = "AzureRunAsConnection"
try {
    # Get the connection "AzureRunAsConnection "
    $servicePrincipalConnection = Get-AutomationConnection -Name $connectionName         

    Write-Output "Logging in to Azure..."
    Add-AzureRmAccount `
        -ServicePrincipal `
        -TenantId $servicePrincipalConnection.TenantId `
        -ApplicationId $servicePrincipalConnection.ApplicationId `
        -CertificateThumbprint $servicePrincipalConnection.CertificateThumbprint | Out-Null
}
catch {
    if (!$servicePrincipalConnection) {
        $ErrorMessage = "Connection $connectionName not found."
        throw $ErrorMessage
    }
    else {
        Write-Error -Message $_.Exception
        throw $_.Exception
    }
}

# If no Command was given (during run by Scheduler) load the last command from the storage table
if (-not($Command)) {
    Write-Output "Getting command from storage table..."
    $currentValues = Get-CurrentTableValues -ResourceGroupName $ResourceGroupName -VmName $VmName -StorageAccountUri $StorageAccountUri -SharedAccessSignature $SharedAccessSignature            
    $Command = $currentValues.Command
}

if (-not($Command)) {
    Write-Output "No Command given. Exiting here."
    return
}

Write-Output "Command is: $Command..."
switch ($Command) {
    'Start' {
        Write-Output "Starting VM '$VmName'..."
        Start-AzureRmVM -Name $VmName -ResourceGroupName $ResourceGroupName | Out-Null
        Write-Output "VM '$VmName' started."
        # Update status in Table
        Update-CommandInTable -ResourceGroupName $ResourceGroupName -VmName $VmName -StorageAccountUri $StorageAccountUri -SharedAccessSignature $SharedAccessSignature
    }
    'Stop' {
        # Get the current values from the Storage Table; "Shutdown" should only be executed, if the command is at least 15 minutes old (to avoid shutting down when the next build is already about to start)
        $currentValues = Get-CurrentTableValues -ResourceGroupName $ResourceGroupName -VmName $VmName -StorageAccountUri $StorageAccountUri -SharedAccessSignature $SharedAccessSignature        
        if ($currentValues.Command -eq 'Stop') {
            if (((Get-Date) - ([datetime]$currentValues.Timestamp)).Minutes -ge 15) {
                Write-Output "Stopping VM '$VmName'..."
                Stop-AzureRmVM -Name $VmName -ResourceGroupName $ResourceGroupName -Force | Out-Null
                Write-Output "VM '$VmName' stopped."
                # Update status in Table
                Update-CommandInTable -ResourceGroupName $ResourceGroupName -VmName $VmName -StorageAccountUri $StorageAccountUri -SharedAccessSignature $SharedAccessSignature
            }
            else {
                Write-Output "Shutdown not yet executed."
            }
        }
    }
}