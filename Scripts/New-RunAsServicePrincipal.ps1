# See: https://windowsserver.uservoice.com/forums/295047-general-feedback/suggestions/38601949-powershell-method-of-provisioning-the-azure-automa
# https://s3.amazonaws.com/uploads.uservoice.com/assets/214/750/171/original/New-RunAsServicePrincipal.txt?X-Amz-Algorithm=AWS4-HMAC-SHA256&X-Amz-Credential=AKIAJF4UXUF6KJMEJFQQ%2F20191121%2Fus-east-1%2Fs3%2Faws4_request&X-Amz-Date=20191121T184248Z&X-Amz-Expires=1800&X-Amz-SignedHeaders=host&X-Amz-Signature=f34345230fe9b1e90b9710a2002e0dee1905fd48bfbbba05b7f0caa915e1a368
function New-RunAsServicePrincipal
{
    Param (
        [Parameter(Mandatory = $true)]
        [String] $rgName,
        [Parameter(Mandatory = $true)]
        [String] $AutomationAccountName,
        [Parameter(Mandatory = $true)]
        [String] $ApplicationDisplayName,
        [Parameter(Mandatory = $true)]
        [String] $SubscriptionId,
        [Parameter(Mandatory = $true)]
        [String] $SelfSignedCertPlainPassword,
        [Parameter(Mandatory = $false)]
        [string]$AzureEnvironment,
        [Parameter(Mandatory = $false)]
        [int] $SelfSignedCertNoOfMonthsUntilExpired = 12
    ) # end param

    # Create self-signed certificate
    function New-SelfSignedCertificateForRunAsAccount
    {
        param
        (
            [string] $CertificateAssetName,
            [string] $selfSignedCertPlainPassword,
            [string] $certPath,
            [string] $certPathCer,
            [string] $selfSignedCertNoOfMonthsUntilExpired
        ) # end param

        $Cert = New-SelfSignedCertificate -DnsName $$CertificateAssetName `
        -CertStoreLocation cert:\LocalMachine\My `
        -KeyExportPolicy Exportable `
        -Provider "Microsoft Enhanced RSA and AES Cryptographic Provider" `
        -NotAfter (Get-Date).AddMonths($selfSignedCertNoOfMonthsUntilExpired) `
        -HashAlgorithm SHA256

        $CertPassword = ConvertTo-SecureString $selfSignedCertPlainPassword -AsPlainText -Force
        Export-PfxCertificate -Cert ("Cert:\localmachine\my\" + $Cert.Thumbprint) -FilePath $certPath -Password $CertPassword -Force | Write-Verbose
        Export-Certificate -Cert ("Cert:\localmachine\my\" + $Cert.Thumbprint) -FilePath $certPathCer -Type CERT | Write-Verbose
    } # end function

    # Create the RunAs Account
    function New-ServicePrincipalForRunAsAccount
    {
        param
        (
            [System.Security.Cryptography.X509Certificates.X509Certificate2] $PfxCert,
            [string] $ApplicationDisplayName
        ) # end param

        $keyValue = [System.Convert]::ToBase64String($PfxCert.GetRawCertData())
        $keyId = (New-Guid).Guid

        # Create an Azure AD application, AD App Credential, AD ServicePrincipal
        $homePage = "www." + $ApplicationDisplayName.ToLower() + ".com"
        # Requires Application Developer Role, but works with Application administrator or GLOBAL ADMIN
        New-AzADApplication -DisplayName $ApplicationDisplayName -HomePage ("http://" + $homePage) -IdentifierUris ("http://" + $keyId)
        $applicationId = (Get-AzAdApplication -DisplayName $ApplicationDisplayName | Where-Object {$_.IdentifierUris[0] -match $keyId}).ApplicationId.guid
        # Requires Application administrator or GLOBAL ADMIN
        # $ApplicationCredential = New-AzADAppCredential -ApplicationId $Application.ApplicationId -CertValue $keyValue -StartDate $PfxCert.NotBefore -EndDate $PfxCert.NotAfter
        New-AzADAppCredential -ApplicationId $applicationId -CertValue $keyValue -StartDate $PfxCert.NotBefore -EndDate $PfxCert.NotAfter
        # Requires Application administrator or GLOBAL ADMIN
        New-AzADServicePrincipal -ApplicationId $applicationId
        # New-AzADServicePrincipal -ApplicationId $Application.ApplicationId -PasswordCredential $ApplicationCredential
        # $servicePrincipalObj = Get-AzADServicePrincipal -ObjectId $ServicePrincipal.Id
        # Sleep here for a few seconds to allow the service principal application to become active (ordinarily takes a few seconds)
        Start-Sleep -Seconds 15
        # Requires User Access Administrator or Owner.
        $NewRole = New-AzRoleAssignment -ApplicationId $applicationId -RoleDefinitionName Contributor -ErrorAction SilentlyContinue
        $Retries = 0;
        While ($null -eq $NewRole -and $Retries -le 6)
        {
            Start-Sleep -Seconds 10
            New-AzRoleAssignment -ApplicationId $applicationId -RoleDefinitionName Contributor | Write-Verbose -ErrorAction SilentlyContinue
            $NewRole = Get-AzRoleAssignment -ServicePrincipalName $applicationId -ErrorAction SilentlyContinue
            $Retries++;
        } # end while
        return $applicationId
    } # end function

    # Create the certificate asset
    function New-AutomationCertificateAsset
    {
        param
        (
            [string] $resourceGroup,
            [string] $automationAccountName,
            [string] $certificateAssetName,
            [string] $certPath,
            [string] $certPlainPassword,
            [Boolean] $Exportable
        ) # end param

        $CertPassword = ConvertTo-SecureString $certPlainPassword -AsPlainText -Force
        Remove-AzAutomationCertificate -ResourceGroupName $resourceGroup -AutomationAccountName $automationAccountName -Name $certificateAssetName -ErrorAction SilentlyContinue -Verbose
        New-AzAutomationCertificate -AutomationAccountName $automationAccountName -Name $certificateAssetName -Path $certPath -Description $certificateAssetName -Password $CertPassword -ResourceGroupName $resourceGroup -Exportable:$Exportable  | write-verbose
    } # end function

    # Create the connection asset
    function New-AutomationConnectionAsset
    {
        param
        (
            # We had to overwrite the value for the $resourceGroup parameter and then later extract a substring of 19 characters to avoid the issue filed at:
            # https://windowsserver.uservoice.com/forums/301869-powershell/suggestions/38585344-new-azautomationconnection-cmdlet-incorrectly-stat
            #[string] $resourceGroup = (Get-AzResourceGroup | Where-Object {$_.ResourceGroupName -match 'app'} | Select-Object -Property ResourceGroupName).ResourceGroupName,
            [string] $resourceGroup,
            [string] $automationAccountName,
            [string] $connectionAssetName,
            [string] $connectionTypeName,
            [System.Collections.Hashtable] $connectionFieldValues
        ) # end params

        #[string]$resourceGroup = $resourceGroup.Substring(0,19)
        Remove-AzAutomationConnection -ResourceGroupName $resourceGroup -AutomationAccountName $automationAccountName -Name $connectionAssetName -Force -ErrorAction SilentlyContinue -Verbose
        New-AzAutomationConnection -ResourceGroupName $resourceGroup -AutomationAccountName $automationAccountName -Name $connectionAssetName -ConnectionTypeName $connectionTypeName -ConnectionFieldValues $connectionFieldValues

    } # end function

    # Create a Run As account by using a service principal
    $CertificateAssetName = $AutomationAccountName + "-RunAsCert"
    $ConnectionAssetName = "AzureRunAsConnection"
    $ConnectionTypeName = "AzureServicePrincipal"

    $PfxCertPathForRunAsAccount = Join-Path $env:TEMP -ChildPath ($CertificateAssetName + ".pfx")
    $PfxCertPlainPasswordForRunAsAccount = $SelfSignedCertPlainPassword
    $CerCertPathForRunAsAccount = Join-Path $env:TEMP -ChildPath ($CertificateAssetName + ".cer")

    New-SelfSignedCertificateForRunAsAccount -CertificateAssetName $CertificateAssetName `
    -SelfSignedCertPlainPassword $SelfSignedCertPlainPassword `
    -certPath $PfxCertPathForRunAsAccount `
    -certPathCer $CerCertPathForRunAsAccount `
    -selfSignedCertNoOfMonthsUntilExpired  $SelfSignedCertNoOfMonthsUntilExpired

    # Create the Automation certificate asset
    New-AutomationCertificateAsset -resourceGroup $rgName `
    -automationAccountName $AutomationAccountName `
    -certificateAssetName $CertificateAssetName `
    -certPath $PfxCertPathForRunAsAccount `
    -certPlainPassword $PfxCertPlainPasswordForRunAsAccount `
    -Exportable $true
    # Wait for 2 minutes to avoid a race condition to allow the RunAs Account time to populate the certificate attributes.
    Start-Sleep -Seconds 120
    # Create a service principal
    $PfxCert = New-Object -TypeName System.Security.Cryptography.X509Certificates.X509Certificate2 -ArgumentList @($PfxCertPathForRunAsAccount, $PfxCertPlainPasswordForRunAsAccount)
    $applicationId = New-ServicePrincipalForRunAsAccount -PfxCert $PfxCert -applicationDisplayName $ApplicationDisplayName
    [guid]$applicationId = ($applicationId)[0].ApplicationId

    # Populate the ConnectionFieldValues
    $SubscriptionInfo = Get-AzSubscription -SubscriptionId $SubscriptionId
    $TenantID = $SubscriptionInfo | Select-Object TenantId -First 1
    $Thumbprint = $PfxCert.Thumbprint
    $ConnectionFieldValues = @{"ApplicationId" = $applicationId; "TenantId" = $TenantID.TenantId; "CertificateThumbprint" = $Thumbprint; "SubscriptionId" = $SubscriptionId}

    # Create an Automation connection asset named AzureRunAsConnection in the Automation account. This connection uses the service principal.
    New-AutomationConnectionAsset -resourceGroup $rgName `
    -automationAccountName $AutomationAccountName `
    -connectionAssetName  $ConnectionAssetName `
    -ConnectionTypeName  $ConnectionTypeName `
    -ConnectionFieldValues $ConnectionFieldValues

} # end function