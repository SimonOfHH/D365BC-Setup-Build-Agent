function Global:Initialize-Dependencies {
    [CmdletBinding()]
    param(        
    )
    process {
        Write-Host "Initializing dependencies..."
        #$neededModules = @("AzuredevOpsAPIUtils","Az.Automation","Az.Accounts","Az.Storage","AzTable","AzureAD")
        $neededModules = @("AzuredevOpsAPIUtils","Az.Automation","Az.Accounts","Az.Storage")
        foreach($neededModule in $neededModules){
            if (-not(Get-Module -Name $neededModule -ListAvailable)) {
                Write-Host "Installing Module $neededModule..."
                Install-Module $neededModule -Force
            }
        }
        foreach($neededModule in $neededModules){
            if (-not(Get-Module | Where-Object {$_.Name -eq $neededModule})) {
                Write-Host "Importing Module $neededModule..."
                Import-Module $neededModule
            }
        }
    }    
}