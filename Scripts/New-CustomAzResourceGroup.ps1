function Global:New-CustomAzResourceGroup {
    [CmdletBinding()]
    param(        
        [Parameter(Mandatory = $true, Position = 0)]
        [string]
        $ResourceGroupName,        
        [Parameter(Mandatory = $true, Position = 1)]
        [string]
        $ResourceLocation,
        [Parameter(Mandatory = $true, Position = 2)]
        [bool]
        $CreateIfNotExisting
    )
    process {
        Write-Host "Checking if Resource Group already exists..."
        $resourceGroup = Get-AzResourceGroup -Name $ResourceGroupName -Location $resourceLocation -ErrorAction SilentlyContinue
        if (-not($resourceGroup)) {
            if ($CreateIfNotExisting) {
                $resourceGroup = New-AzResourceGroup -Name $ResourceGroupName -Location $ResourceLocation
            }
            else {
                Write-Error "Resource Group '$ResourceGroupName' does not exist."
            }
        } else {
            Write-Host "Resource Group $ResourceGroupName already exists."
        }
        $resourceGroup
    }    
}