function Global:Get-VariableBodyFromObject {
    [CmdletBinding()]
    param(       
        [Parameter(Mandatory = $true)]
        $Variables
    )
    process {
        $variableParent = @{ }
        foreach ($variableObject in $Variables) {
            $variableValue = @{"value" = $variableObject.Value }
            if ($variableObject.IsSecret){
                $variableValue.Add("isSecret", $true)
            }
            $variableParent.Add($variableObject.Name, $variableValue)
        }
        $variableParent | ConvertTo-Json
    }    
}