function Global:Get-CustomVariableGroup {
    [CmdletBinding()]
    param(        
        [Parameter(Mandatory = $true)]
        [string]
        $GroupName,
        [Parameter(Mandatory = $true)]
        [string]
        $DevOpsOrganisation,
        [Parameter(Mandatory = $true)]
        [string]
        $DevOpsProject,
        [Parameter(Mandatory = $true)]
        [string]
        $VstsToken
    )
    process {
        $uri = "https://dev.azure.com/$DevOpsOrganisation/$DevOpsProject/_apis/distributedtask/variablegroups?groupName=$($GroupName)&api-version=5.1-preview.1"
        $headers = @{ "Authorization" = "Basic $([System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes("vsts:$VstsToken")))"; "Content-Type" = "application/json"; }
                
        $json = (Invoke-WebRequest -Method Get -uri $uri -Headers $headers -UseBasicParsing).Content | ConvertFrom-Json
        if ($json.count -ne 0){
            $existingGroup = $json.value | Select-Object -First 1
            $existingGroup.variables
        }
    }    
}