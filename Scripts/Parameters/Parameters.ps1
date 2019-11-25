$subscriptionName = "<Your Subscription Name>"

$resourceGroupName = "<Resource Group Name>"                        # Change to your desired value, e.g. "BC-BuildAgents"
$resourceLocation = 'West Europe'

$vmName = "agent-01"                                                # Change to your desired value
$vmAdminUser = "<Admin Username for VM>"                            # Change to your desired value
$vmadminPass = "<Admin Password for VM>"                            # Change to your desired value

$devOpsOrganisation = "<Your DevOps Organisation>"                  # The part after "https://dev.azure.com" in the URL of your project (for "https://dev.azure.com/OrganisationName/ProjectName/" it would be "OrganisationName")
$devOpsProject = "<Your DevOps Project>"                            # The part after "https://dev.azure.com" and the organisation in the URL of your project (for "https://dev.azure.com/OrganisationName/ProjectName/" it would be "ProjectName")
$devOpsOrganisationUri = "https://dev.azure.com/$devOpsOrganisation"
$vstsToken = "<Token from DevOps>"                                  # The beginning of a token looks like this: wbsffbx46u.... (total around 52 characters)
$poolName = "D365-ALOps"                                            # Name of the Agent Pool in DevOps; Change to your desired value
$finalSetupScriptUrl = "https://raw.githubusercontent.com/SimonOfHH/D365BC-Setup-Build-Agent/master/vm-preparation-script.ps1" # This script is executed after the VM is created

# These are values for the Power Management of the VM (agent VM automatically starts/stops when necessary to avoid too high costs for VM)
# You can update these as well if you want
$automationAccountName = "AgentAutomationAccount"
$automationRunbookName = "AgentPowerManagement"
$automationRunbookScheduleName = "BookSchedule"