function Global:New-CustomAzStorageTable {
    [CmdletBinding()]
    param(        
        [Alias('TableName')]
        [Parameter(Mandatory = $true, Position = 0)]
        [string]
        $StorageAccountSetupTableName,        
        [Alias('Context')]
        [Parameter(Mandatory = $true, Position = 1)]
        [object]
        $StorageAccountContext
    )
    process {
        Write-Host "Checking if Storage Account Table already exists..."
        $storageAccountTable = Get-AzStorageTable -Name $StorageAccountSetupTableName -Context $StorageAccountContext -ErrorAction SilentlyContinue
        if (-not($storageAccountTable )) {
            Write-Host "Creating Storage Account Table $storageAccountSetupTableName..."
            $storageAccountTable = New-AzStorageTable -Name $storageAccountSetupTableName -Context $StorageAccountContext
            Write-Host "Storage Account Table '$storageAccountSetupTableName' created"
        }
        $storageAccountTable
    }    
}