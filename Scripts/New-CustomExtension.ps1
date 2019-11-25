function Global:New-CustomExtension {
    [CmdletBinding()]
    param(        
        [Parameter(Mandatory = $false)]
        [string]
        $PublisherName = "hodor",
        [Parameter(Mandatory = $false)]
        [string]
        $ExtensionName = "hodor-alops",        
        [Parameter(Mandatory = $true)]
        [string]
        $DevOpsOrganisation,        
        [Parameter(Mandatory = $true)]
        [string]
        $VstsToken
    )
    process {
        $uri = "https://extmgmt.dev.azure.com/$DevOpsOrganisation/_apis/extensionmanagement/installedextensionsbyname/$($PublisherName)/$($ExtensionName)?api-version=5.1-preview.1"
        $headers = @{ "Authorization" = "Basic $([System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes("vsts:$VstsToken")))"; "Content-Type" = "application/json"; }

        Write-Host "Checking if Extension $ExtensionName exists..."
        $response = $null
        try {
            $response = Invoke-RestMethod -Method Get -uri $uri -Headers $headers -UseBasicParsing
        } catch {
            #$response
            $response = [System.Net.HttpWebResponse]$_.Exception.Response
        }
        if ($response.StatusCode.value__ -eq 404){
            Write-Host "Installing Extension $ExtensionName since it doesn't exist..." -ForegroundColor Yellow
            $uri = "https://extmgmt.dev.azure.com/$DevOpsOrganisation/_apis/extensionmanagement/installedextensionsbyname/$($PublisherName)/$($ExtensionName)?api-version=5.1-preview.1"
            $response = Invoke-RestMethod -Method Post -uri $uri -Headers $headers -UseBasicParsing
            Write-Host "Done." -ForegroundColor Yellow
        } else {
            Write-Host "Seems that Extension $ExtensionName already exists."
        }
    }    
}