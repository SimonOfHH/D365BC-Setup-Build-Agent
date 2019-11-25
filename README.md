# D365BC-Build-Agent

Helper to get started with your own Build Agent on [Azure](https://portal.azure.com/) for Dynamics 365 Business Central using [ALOps](https://github.com/HodorNV/ALOps) on [Azure DevOps](https://dev.azure.com/).

The PowerShell code is probably not best-practice, but it's meant as a starting point for people having trouble getting started :-)

## Info

Clone this repository, update [Parameters.ps1](https://github.com/SimonOfHH/D365BC-Setup-Build-Agent/blob/master/Scripts/Parameters/Parameters.ps1) in sub-directory "Parameters" and run it. When the script is completed you'll have
1. A new Build Agent VM (based on Freddys template (https://raw.githubusercontent.com/microsoft/nav-arm-templates/master/buildagent.json))
2. A scheduled RunBook that automatically starts/stops the VM to avoid high costs
3. (Almost) all necessary elements in your DevOps repository to get started (see documentation in [RunSetup.ps1](https://github.com/SimonOfHH/D365BC-Setup-Build-Agent/blob/master/Scripts/RunSetup.ps1))