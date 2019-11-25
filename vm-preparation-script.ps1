# Install Choco
Set-ExecutionPolicy Bypass -Scope Process -Force; iex ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))
# Install Git
choco install -y git
choco upgrade -y git
# Install UPack
choco install -y upack
choco upgrade -y upack
# Install Azure CLI
choco install -y azure-cli 
choco upgrade -y azure-cli
# Install Google Chrome
choco install -y googlechrome
choco upgrade -y googlechrome
# Reload the PATH variable
$env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine")
# Install Azure CLI Extension for Azure-DevOps
az extension add --name azure-devops

# Install VSCode
choco install -y vscode
choco upgrade -y vscode
# Reload the PATH variable
$env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine")
# Install VS-Code Extensions for AL
try { code --install-extension file-icons.file-icons | Out-Null } catch {}
try { code --install-extension andrzejzwierzchowski.al-code-outline | Out-Null } catch {}
try { code --install-extension rasmus.al-formatter | Out-Null } catch {}
try { code --install-extension martonsagi.al-object-designer | Out-Null } catch {}
try { code --install-extension davidanson.vscode-markdownlint | Out-Null } catch {}
try { code --install-extension hnw.vscode-auto-open-markdown-preview | Out-Null } catch {}
try { code --install-extension eriklynd.json-tools | Out-Null } catch {}
try { code --install-extension waldo.crs-al-language-extension | Out-Null } catch {}
try { code --install-extension donjayamanne.githistory | Out-Null } catch {}
try { code --install-extension eamodio.gitlens | Out-Null } catch {}
try { code --install-extension heaths.vscode-guid | Out-Null } catch {}
try { code --install-extension streetsidesoftware.code-spell-checker | Out-Null } catch {} 

if (-not (Get-PackageProvider -ListAvailable | Where-Object { $_.Name -eq 'NuGet' })) {
    try {
        Write-CustomHost -Message "Installing NuGet..."
        Install-PackageProvider -Name NuGet -Confirm:$False -Force | Out-Null
    }
    catch [Exception] {
        Write-CustomHost -Message "Error installing NuGet"
        $_.message 
        exit
    }
}
