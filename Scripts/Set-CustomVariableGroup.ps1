function Global:Set-CustomVariableGroup {
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
        $VstsToken,
        [Parameter(Mandatory = $true)]
        $Variables
    )
    process {
        $uri = "https://dev.azure.com/$DevOpsOrganisation/$DevOpsProject/_apis/distributedtask/variablegroups?api-version=5.1-preview.1"
        $headers = @{ "Authorization" = "Basic $([System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes("vsts:$VstsToken")))"; "Content-Type" = "application/json"; }
        $variablesJson = Get-VariableBodyFromObject -Variables $Variables
        $body = @{ "name" = $GroupName; "description" = "Created by Setup Script"; "type" = "Vsts"; "variables" = $variablesJson } | ConvertTo-Json -Compress
        
        # If group is already existing, get the ID and do a PUT to update it
        $json = (Invoke-WebRequest -Method Get -uri $uri -Headers $headers -UseBasicParsing).Content | ConvertFrom-Json
        if ($json.count -ne 0){
            $existingGroup = $json.value | Where-Object { $_.name -eq "CI ALOps" }
            if ($existingGroup){
                $id = $existingGroup.id
                foreach ($variable in $Variables){
                    if ($json.value.variables.($variable.Name)){
                        #"Variable $($variable.Name) existing"
                        $json.value.variables.($variable.Name).value = $variable.Value
                    } else {
                        #"Variable $($variable.Name) not existing"
                        $json.value.variables | Add-Member -NotePropertyMembers @{$variable.Name=[pscustomobject]@{value=$variable.Value}}
                    }
                }
                $body = @{ "name" = $GroupName; "description" = "Created by Setup Script"; "type" = "Vsts"; "variables" = $json.value.variables } | ConvertTo-Json -Compress
                Write-Host "Updating variable-group $($GroupName)" -f Yellow
                $uri = "https://dev.azure.com/$DevOpsOrganisation/$DevOpsProject/_apis/distributedtask/variablegroups/$($id)?api-version=5.1-preview.1"
                return ((Invoke-WebRequest -Method Put -Body $body -uri $uri -Headers $headers -UseBasicParsing).Content | ConvertFrom-Json)
            } else {
                Write-Host "Add variable-group $($GroupName) to '$DevOpsOrganisation/$DevOpsProject'" -f Yellow
                Write-Host "You'll need to go to the variable group on the page and set 'Allow access to all pipelines' manually." -f Yellow
                return ((Invoke-WebRequest -Method Post -Body $body -uri $uri -Headers $headers -UseBasicParsing).Content | ConvertFrom-Json)
            }
        } else {
            Write-Host "Add variable-group $($GroupName) to '$DevOpsOrganisation/$DevOpsProject'" -f Yellow
            Write-Host "You'll need to go to the variable group on the page and set 'Allow access to all pipelines' manually." -f Yellow
            return ((Invoke-WebRequest -Method Post -Body $body -uri $uri -Headers $headers -UseBasicParsing).Content | ConvertFrom-Json)
        }
    }    
}