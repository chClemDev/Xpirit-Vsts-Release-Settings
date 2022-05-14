[cmdletbinding()]
param(
[String] [Parameter(Mandatory = $true)]
    $ConnectedServiceName,

    [String] [Parameter(Mandatory = $true)]
    $WebAppName,

    [String] [Parameter(Mandatory = $true)]
    $DeployToSlotFlag,

    [String] [Parameter(Mandatory = $false)]
    $ResourceGroupName,

    [String] [Parameter(Mandatory = $false)]
    $SlotName,
	
	[String] [Parameter(Mandatory = $true)]
    $ValidateFlag,

	[String] [Parameter(Mandatory = $true)]
    $WebConfigFile,
	[string] $validationResultAction,
	[string] $Cleanup = "true"
)

Write-Verbose "Entering script $($MyInvocation.MyCommand.Name)"
Write-Verbose "Parameter Values"
$PSBoundParameters.Keys | %{ Write-Verbose "$_ = $($PSBoundParameters[$_])" }

Write-Verbose "Importing modules"
# import-module "Microsoft.TeamFoundation.DistributedTask.Task.Internal"
# import-module "Microsoft.TeamFoundation.DistributedTask.Task.Common"

# $settingHelperPath = "./Modules\Xpirit.Vsts.Release.SettingHelper.dll"
# import-module $settingHelperPath

import-module "./ps_modules/VstsTaskSdk/VstsTaskSdk.psd1"

# Import-Module -Name $PSScriptRoot\ps_modules\VstsTaskSdk\VstsTaskSdk.psm1
# Import-VstsLocStrings "$PSScriptRoot\Task.json"

$agentVersion = Get-VstsTaskVariable -Name 'agent.Version'

Write-Verbose "agentVersion : $agentVersion"

#Convert string parameters to bools
$Clean = (Convert-String $Cleanup Boolean)
$Validate = (Convert-String $ValidateFlag Boolean)

$script:knownVariables2 = @{ }


# function Get-VariableKey-Debug {
#     [CmdletBinding()]
#     param(
#         [Parameter(Mandatory = $true)]
#         [string]$Name)

#     if ($Name -ne 'agent.jobstatus') {
#         $Name = $Name.Replace('.', '_')
#     }

#     $Name.ToUpperInvariant()
# }


# function Debug-Variable-Result-Set()
# {
# 	Write-Verbose "Debug-Variable-Result-Set"

# 	foreach ($variable in (Get-ChildItem -Path Env:ENDPOINT_?*, Env:INPUT_?*, Env:SECRET_?*, Env:SECUREFILE_?*)) {
#         # Record the secret variable metadata. This is required by Get-TaskVariable to
#         # retrieve the value. In a 2.104.1 agent or higher, this metadata will be overwritten
#         # when $env:VSTS_SECRET_VARIABLES is processed.
#         if ($variable.Name -like 'SECRET_?*') {
#             $variableKey = $variable.Name.Substring('SECRET_'.Length)
#             $script:knownVariables2[$variableKey] = New-Object -TypeName psobject -Property @{
#                 # This is technically not the variable name (has underscores instead of dots),
#                 # but it's good enough to make Get-TaskVariable work in a pre-2.104.1 agent
#                 # where $env:VSTS_SECRET_VARIABLES is not defined.
#                 Name = $variableKey
#                 Secret = $true
#             }
#         }

#         # # Store the value in the vault.
#         # $vaultKey = $variable.Name
#         # if ($variable.Value) {
#         #     $script:vault[$vaultKey] = New-Object System.Management.Automation.PSCredential(
#         #         $vaultKey,
#         #         (ConvertTo-SecureString -String $variable.Value -AsPlainText -Force))
#         # }

# 		Write-Verbose "Removing Item : $variable."

#         # Clear the environment variable.
#         Remove-Item -LiteralPath "Env:$($variable.Name)"
#     }

# 	if ($env:VSTS_PUBLIC_VARIABLES) {
#         foreach ($name in (ConvertFrom-Json -InputObject $env:VSTS_PUBLIC_VARIABLES)) {
#             $variableKey = Get-VariableKeyDebug -Name $name
#             $script:knownVariables2[$variableKey] = New-Object -TypeName psobject -Property @{
#                 Name = $name
#                 Secret = $false
#             }
#         }

#         $env:VSTS_PUBLIC_VARIABLES = ''
#     } else{
# 		Write-Verbose "No VSTS_PUBLIC VARIABLES"
# 	}

# 	# Record the secret variable names. Env var added in 2.104.1 agent.
#     if ($env:VSTS_SECRET_VARIABLES) {
#         foreach ($name in (ConvertFrom-Json -InputObject $env:VSTS_SECRET_VARIABLES)) {
#             $variableKey = Get-VariableKeyDebug -Name $name
#             $script:knownVariables2[$variableKey] = New-Object -TypeName psobject -Property @{
#                 Name = $name
#                 Secret = $true
#             }
#         }

#         $env:VSTS_SECRET_VARIABLES = ''
#     } else{
# 		Write-Verbose "No VSTS_SECRET_VARIABLES"
# 	}

# 	foreach ($info in $script:knownVariables2.Values) {
# 		Write-Verbose $info
# 		# New-Object -TypeName psobject -Property @{
# 		# 	Name = $info.Name
# 		# 	Value = Get-TaskVariable -Name $info.Name
# 		# 	Secret = $info.Secret
# 		# }
# 	}

# 	Write-Verbose "Ending Debug-Variable-Result-Set"
# }

function Read-Variables-From-VSTS()
{
	Write-Verbose "Read-Variables-From-VSTS"
	# Get all variables. Loop through each and apply if needed.
	# $script:vstsVariables = Get-TaskVariables -Context $distributedTaskContext
	$script:vstsVariables = Get-Item -Path Env:*

	# $vstsAllVars = @(Get-VstsTaskVariableInfo)
	# $vstsAllVarsWithOutputs = Get-VstsTaskVariableInfo -ErrorVariable allVarErrors -WarningVariable allVarWarnings -OutVariable allVarOutVariable
	# Write-Verbose "allVarErrors : $allVarErrors" 
	# Write-Verbose "allVarWarnings : $allVarWarnings" 
	# Write-Verbose "allVarOutVariable : $allVarOutVariable" 

	# $vstsAllVars = Get-VstsTaskVariableInfo


	# $allVarErrors | ForEach-Object{ write-host $_}
	# $allVarWarnings | ForEach-Object{ write-host $_}
	# $allVarOutVariable | ForEach-Object{ write-host $_}

	# $vstsSingleVar = Get-VstsTaskVariable -Name 'devOpsOrg'
	# $vstsSingleVarFromAllVars = Get-VstsTaskVariableInfo | Where-Object { $_.Name -eq "devOpsOrg" }
	# $vstsSingleVar2 = Get-VstsTaskVariable -Name 'appsetting.PublicSearchIndexApiKey'
	# $vstsSingleVar3 = Get-VstsTaskVariable -Name 'appsetting_PublicSearchIndexApiKey'
	# $vstsSingleVar4 = Get-VstsTaskVariable -Name 'APPSETTING_PUBLICSEARCHINDEXAPIKEY'
	# $vstsSingleVar5 = Get-VstsTaskVariable -Name 'APPSETTING.PUBLICSEARCHINDEXAPIKEY'
	
	# Write-Verbose "vstsAllVars : $vstsAllVars"
	# Write-Verbose "vstsSingleVarFromAllVars : $vstsSingleVarFromAllVars" 
	# Write-Verbose "vstsSingleVar : $vstsSingleVar"
	# Write-Verbose "vstsSingleVar2 : $vstsSingleVar2"
	# Write-Verbose "vstsSingleVar3 : $vstsSingleVar3"
	# Write-Verbose "vstsSingleVar4 : $vstsSingleVar4"
	# Write-Verbose "vstsSingleVar5 : $vstsSingleVar5"

	# $vstsAllVars.foreach({
	# 	Write-host $_
	# })

	# $script:vstsVariables = Get-TaskVariableInfo

	# Write-Verbose "Variable Values: " $vstsVariables 
	# $vstsVariables.Keys | %{ Write-Verbose "$_ = $($vstsVariables[$_])" }
}

function Output-ValidationResults()
{
	Write-Verbose "Output-ValidationResults. Should Validate: $Validate"
	if ($Validate)
	{
		switch($validationResultAction)
		{
		
			'warn' { 
				foreach ($validationError in $validationErrors) 
				{
					Write-Warning $validationError 
				}
			}
			'fail' { 
				foreach ($validationError in $validationErrors) 
				{
					Write-Error $validationError 
				}
			}
			default { Write-Verbose "No result action selected." } 
		}
	}
}

function Write-Settings-To-WebApp()
{
	Write-Verbose "Write-Settings-To-WebApp"	

	# The appsettings and connectionstrings has to be updated separately because when one of the collections is empty, an exception will be raised.
	if($SlotName){

		if ($settings.Count -gt 0){
			Write-Verbose "Write appsettings to website with deploymentslot"	
			$site = Set-AzureRMWebAppSlot -Name $WebAppName -ResourceGroupName $ResourceGroupName -AppSettings $settings -Slot $SlotName			
		}
		if ($connectionStringsHashTable.Count -gt 0){
			Write-Verbose "Write connectionstrings to website with deploymentslot"	
			$site = Set-AzureRMWebAppSlot -Name $WebAppName -ResourceGroupName $ResourceGroupName -ConnectionStrings $connectionStringsHashTable -Slot $SlotName			
		}
	}
	else
	{
		if ($settings.Count -gt 0){
			Write-Verbose "Write appsettings to website"	
			$site = Set-AzureRMWebApp -Name $WebAppName -ResourceGroupName $ResourceGroupName -AppSettings $settings 
		}
		if ($connectionStringsHashTable.Count -gt 0){
			Write-Verbose "Write connectionstrings to website"			

			$site = Set-AzureRMWebApp -Name $WebAppName -ResourceGroupName $ResourceGroupName -ConnectionStrings $connectionStringsHashTable	
		}
	}
}

function Write-Sticky-Settings()
{
	Write-Verbose "Write-Sticky-Settings"
	$resourceName = $WebAppName + "/slotConfigNames"

	$stickySlot.properties.appSettingNames = $stickyAppSettingNames.ToArray()
	$stickySlot.properties.connectionStringNames = $stickyConnectionStringNames.ToArray()

	Set-AzureRmResource -ResourceName $resourceName -ResourceGroupName $ResourceGroupName -ResourceType "Microsoft.Web/Sites/config" -PropertyObject $stickySlot.properties -ApiVersion "2015-08-01" -Force
}

function Read-WebConfigToPrepareValidation()
{
	Write-Verbose "Read-WebConfigToPrepareValidation. Validate: $Validate"
	if ($Validate)
	{
		#Read web.config
		$xml = [xml] (Get-Content $WebConfigFile)

		Write-Verbose "Start reading appsettings"
		foreach($appSetting in $xml.configuration.appSettings.add)
		{
			$script:appSettingKeys[$appSetting.key] = $appSetting.key
		}
				
		Write-Verbose "Start reading connectionstrings"
		foreach($connectionString in $xml.configuration.connectionStrings.add)
		{
			$script:connectionStringNames[$connectionString.name] = $connectionString.name
		}
	
		
		Write-Verbose "Finished reading config file"		
	}
}

function Read-Settings-From-WebApp()
{
	Write-Verbose "Read-Settings-From-WebApp"

	if($SlotName)
	{
		Write-Verbose "Reading configuration from website $WebAppName and deploymentslot $SlotName" 
		$script:WebSite = Get-AzureRmWebAppSlot -Name $WebAppName -Slot $SlotName -ResourceGroupName $ResourceGroupName
	}
	else
	{
		Write-Verbose "Reading configuration from website $WebAppName" 
		$script:WebSite = Get-AzureRmWebApp -Name $WebAppName -ResourceGroupName $ResourceGroupName
	}
	if(!$WebSite) 
	{
		$error = ("Failed to find WebSite {0}" -f $WebAppName)
		Write-Error $error
		throw $error
	}

	Write-Verbose "Fetch appsettings"
	# Get all appsettings and put in Hashtable (because Set-AzureRMWebApp needs that)
	if (!$Clean)
	{
		ForEach ($kvp in $WebSite.SiteConfig.AppSettings) {
			$settings[$kvp.Name] = $kvp.Value
		}
	}
	Write-Verbose "appsettings: $settings"
	Write-Verbose "Fetch connectionstrings"

	# Get all connectionstrings and put it in a Hashtable (because Set-AzureRMWebApp needs that)	
	if (!$Clean)
	{
		ForEach ($kvp in $WebSite.SiteConfig.ConnectionStrings) {
			$connectionStringsHashTable[$kvp.Name] = @{"Value" = $kvp.ConnectionString.ToString(); "Type" = $kvp.Type.ToString()} #Make sure that Type is a string    
		}
	}
	Write-Verbose "connectionstrings: $connectionStringsHashTable"
}

function Read-Sticky-Settings()
{
	Write-Verbose "Read-Sticky-Settings"
	
	$resourceName = $WebAppName + "/slotConfigNames"
	$script:stickySlot = Get-AzureRmResource -ResourceName $resourceName -ResourceGroupName $ResourceGroupName -ResourceType "Microsoft.Web/sites/config" -ApiVersion "2015-08-01"
	
	if (!$Clean)
	{
		# Fill with all existing settings
		$stickyAppSettingNames.AddRange($script:stickySlot.properties.appSettingNames)
		$stickyConnectionStringNames.AddRange($script:stickySlot.properties.connectionStringNames)
	}
	Write-Verbose "Finished Read-Sticky-Settings"
}

function Validate-WebConfigVariablesAreInVSTSVariables()
{
	Write-Verbose "Validate-WebConfigVariablesAreInVSTSVariables. Validate: $Validate"
	if ($Validate)
	{
		if ($appSettingKeys)
		{
			foreach ($configAppSetting in $appSettingKeys.GetEnumerator()) {
				$configAppSettingName = $configAppSetting.key
				Write-Verbose "Trying to validate appsetting [$configAppSettingName]"
				$found = $settings.Contains($configAppSettingName);
				if (!$found)
				{
					$validationErrors.Add("Cannot find VSTS variable with name [appsetting.$configAppSettingName]. But the key does exist in the web.config")
				}  
			}
		}
		if ($connectionStringNames)
		{
			Write-Verbose "validate connectionstrings"			

			foreach ($configConnectionString in $connectionStringNames.GetEnumerator()) {
				$configConnectionStringName = $configConnectionString.key
				Write-Verbose "Trying to validate connectionstring [$configConnectionStringName]"
				$found = $connectionStringsHashTable.Contains($configConnectionStringName);
				if (!$found)
				{
					$validationErrors.Add("Cannot find VSTS variable with name [connectionstring.$configConnectionStringName]. But the key does exist in the web.config")
				}  
			}
		}
	}
}

function AddSettingAsAppSetting()
{
	param(	
		[string] $originalKey,	
		[string] $cleanKey,
		[string] $value
	)

	if ($originalKey.Contains(".sticky"))
	{
		Write-Verbose "AppSetting $cleanKey added to sticky"
		$stickyAppSettingNames.Add($cleanKey)
	}

	Write-Host "Store appsetting $cleanKey with value $Value"

	$settings[$cleanKey.ToString()] = $Value.ToString();		
		
	if ($Validate -and $appSettingKeys)
	{
		Write-Verbose "Going to validate $cleankey to:"

		$found = $appSettingKeys.Contains($cleanKey);
		if (!$found)
		{
			$validationErrors.Add("Cannot find appSetting [$cleanKey] in web.config. But the key does exist in VSTS as a variable")
		}
		Write-Verbose "Validated"
	}
}

function AddSettingAsConnectionString()
{
	param(		
		[string] $originalKey,
		[string] $cleanKey,
		[string] $value
	)

	Write-Verbose "Start applying connectionstring $cleanKey with value $Value"		
		
    if ($cleanKey.Contains(".sqlazure"))
	{
		$cleanKey = $cleanKey.Replace(".sqlazure", "")
		$type = "SQLAzure"            
	}
	elseif ($cleanKey.Contains(".custom"))
	{
		$cleanKey = $cleanKey.Replace(".custom", "")			
        $type = "Custom"
	}
	elseif ($cleanKey.Contains(".sqlserver"))
	{
		$cleanKey = $cleanKey.Replace(".sqlserver", "")			
        $type = "SQLServer"
	}
	elseif ($cleanKey.Contains(".mysql"))
	{
		$cleanKey = $cleanKey.Replace(".mysql", "")			
        $type = "MySql"
	}
	else
	{
		$error = ("No database type given for connectionstring name {0} for website {1}. use naming convention: connectionstring.yourconnectionstring.sqlserver.sticky" -f $cleanKey, $WebAppName)
		Write-Error $error
		throw $error
	}   			
		
	if ($Validate -and $connectionStringNames)
	{
		$found = $connectionStringNames.Contains($cleanKey);
		if (!$found)
		{
			$validationErrors.Add("Cannot find connectionString [$cleanKey] in web.config. But the key does exist in VSTS as a variable")
		}       
	}

	if ($originalKey.Contains(".sticky"))
	{
		Write-Verbose "Connectionstring $cleanKey added to sticky"
		$stickyConnectionStringNames.Add($cleanKey)  
	}

	Write-Host "Store connectionstring $cleanKey with value $Value of type $type"
	$connectionStringsHashTable[$cleanKey] = @{"Value" = $Value.ToString(); "Type" = $type.ToString()}
}

$validationErrors = New-Object 'System.Collections.Generic.List[string]'

$stickySlot = $null
$stickyAppSettingNames = New-Object 'System.Collections.Generic.List[object]'
$stickyConnectionStringNames = New-Object 'System.Collections.Generic.List[object]'

$WebSite = $null
$settings = @{}
$connectionStringsHashTable = @{}
$vstsVariables = @{}

$appSettingKeys = @{}
$connectionStringNames = @{}

Read-WebConfigToPrepareValidation
Read-Settings-From-WebApp
Read-Sticky-Settings
Read-Variables-From-VSTS
# Debug-Variable-Result-Set

# foreach ($h in $vstsVariables.GetEnumerator()) {
$vstsVariables.foreach({
	Write-Verbose "Processing vstsvariable: $($_.Name): $($_.Value)"

	$originalKey = $_.Name
	$cleanKey = $originalKey.Replace(".sticky", "").Replace("appsetting.", "").Replace("connectionstring.", "")
	# $Value = Get-TaskVariable $distributedTaskContext $originalKey
	$value = Get-VstsTaskVariable -Name $originalKey

	if ($originalKey.StartsWith("appsetting."))
	{	
		AddSettingAsAppSetting -originalKey $originalKey -cleanKey $cleanKey -value $value
	}
	elseif ($originalKey.StartsWith("connectionstring."))
	{		
		AddSettingAsConnectionString -originalKey $originalKey -cleanKey $cleanKey -value $value
	}
})
	
# }

Validate-WebConfigVariablesAreInVSTSVariables

Output-ValidationResults
if ($Validate -and $validationErrors.Count -gt 0 -and $validationResultAction -eq "fail")
{
	Write-Host "Not writing the settings to the webapp because there are validation errors and the validation action result is fail"		
}
else
{
	Write-Settings-To-WebApp
	Write-Sticky-Settings
}
Write-Verbose "##vso[task.complete result=Succeeded;]DONE"


