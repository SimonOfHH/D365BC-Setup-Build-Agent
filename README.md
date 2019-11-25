# D365BC Setup Build Agent

Helper to get started with your own Build Agent on [Azure](https://portal.azure.com/) for Dynamics 365 Business Central using [ALOps](https://github.com/HodorNV/ALOps) on [Azure DevOps](https://dev.azure.com/).

The PowerShell code is probably not best-practice, but it's meant as a starting point for people having trouble getting started :blush:

## Info

Clone this repository, update [Parameters.ps1](https://github.com/SimonOfHH/D365BC-Setup-Build-Agent/blob/master/Scripts/Parameters/Parameters.ps1) in sub-directory "Parameters" and run it. When the script is completed you'll have
1. A new Build Agent VM (based on Freddys template (https://raw.githubusercontent.com/microsoft/nav-arm-templates/master/buildagent.json))
2. A scheduled RunBook that automatically starts/stops the VM to avoid high costs
3. (Almost) all necessary elements in your DevOps repository to get started (see documentation in [RunSetup.ps1](https://github.com/SimonOfHH/D365BC-Setup-Build-Agent/blob/master/Scripts/RunSetup.ps1))

## Thanks to
- [FreddyDK](https://github.com/freddydk) for just everything :blush:
- [HodorNV](https://github.com/HodorNV/ALOps)/[waldo](https://github.com/waldo1001/) for ALOps and the pipeline-templates
- [Megel](https://github.com/megel/Azure-DevOps-Agents-for-BC-Examples) for his examples
- and of course the many, many StackOverflow-/TechNet-post that helped :wink: