function Global:New-CustomAgentPool {
    [CmdletBinding()]
    param(        
        [Parameter(Mandatory = $true, Position = 0)]
        [string]
        $PoolName,        
        [Parameter(Mandatory = $true, Position = 1)]
        [string]
        $DevOpsOrganisation,        
        [Parameter(Mandatory = $true, Position = 2)]
        [string]
        $VstsToken
    )
    process {
        Write-Host "Checking if Agent Pool $PoolName exists..."
        $pools = (Get-AzureDevOpsAgentPools -organizationUri $DevOpsOrganisation -vstsToken $VstsToken)
        $pool = ($pools | Where-Object { $_.name -eq $PoolName } | Select-Object -First 1)
        if (-not($pool)) {
            Write-Host "Creating Agent Pool $PoolName..."
            $pool = (Add-AzureDevOpsAgentPool -name $PoolName -organizationUri $DevOpsOrganisation -vstsToken $VstsToken)
        }
        else {
            Write-Host "Agent Pool $PoolName already exists"
        }
    }    
}