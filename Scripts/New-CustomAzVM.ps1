function Global:New-CustomAzVM {
    [CmdletBinding()]
    param(        
        [Parameter(Mandatory = $true, Position = 0)]
        [string]
        $ResourceGroupName,        
        [Parameter(Mandatory = $true, Position = 1)]
        [string]
        $VMName,
        [Parameter(Mandatory = $true, Position = 2)]
        [string]
        $VmAdminUser,
        [Parameter(Mandatory = $true, Position = 3)]
        [string]
        $VmAdminPass,
        [Parameter(Mandatory = $true, Position = 4)]
        [string]
        $PoolName,        
        [Parameter(Mandatory = $true, Position = 5)]
        [string]
        $DevOpsOrganisation,        
        [Parameter(Mandatory = $true, Position = 6)]
        [string]
        $VstsToken,        
        [Parameter(Mandatory = $true, Position = 7)]
        [string]
        $SetupScript,        
        [Parameter(Mandatory = $false, Position = 8)]
        [string]
        $VmTemplateUri = "https://raw.githubusercontent.com/microsoft/nav-arm-templates/master/buildagent.json",
        [Parameter(Mandatory = $false, Position = 9)]
        [string]
        $VstsAgentUrl = "https://vstsagentpackage.azureedge.net/agent/2.160.1/vsts-agent-win-x64-2.160.1.zip",        
        [Parameter(Mandatory = $false, Position = 10)]
        [string]
        $VMSize = "Standard_D4_v3",        
        [Parameter(Mandatory = $false, Position = 11)]
        [string]
        $OperatingSystem = "Windows Server 2019 with Containers"
    )
    process {
        Write-Host "Checking if VM $VMName already exists..."
        $VirtualMachine = Get-AzVM -ResourceGroupName $ResourceGroupName -Name $VMName -ErrorAction SilentlyContinue
        if (-not($VirtualMachine)) {
            Write-Host "Deploying VM Template..."
            $params = @{
                vmName              = $VMName        
                vmAdminUsername     = $VmAdminUser
                adminPassword       = $VmAdminPass        
                OperatingSystem     = $OperatingSystem
                vmSize              = $VMSize
                RemoteDesktopAccess = "*"
                VstsAgentUrl        = $VstsAgentUrl
                DevOpsOrganization  = $DevOpsOrganisation
                Pool                = $PoolName
                PersonalAccessToken = $VstsToken
                FinalSetupScriptUrl = $SetupScript
            }
            New-AzResourceGroupDeployment -ResourceGroupName $ResourceGroupName `
                -TemplateUri $VmTemplateUri `
                -TemplateParameterObject $params | Out-Null
            Write-Host "VM Deployment finished."
        }
        else {
            Write-Host "VM $VMName already exists."
        }
    }    
}