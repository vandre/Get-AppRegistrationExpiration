1	Overview
Solution was designed for the purpose of providing the ability to monitor and notify in the event of App Registration\Service Principal Name (SPN) secret key or certificate coming within the threshold of expiring. The solution is designed to be cross tenant and requires an App Registration\SPN in the desired environment with Global Reader rights. Utilizing Azure Automation (AA) and AA resources like Variables and Credentials our runbook pulls an array of SPN’s from the environment and calculates the time until expiration before using our custom function to send the data to a Log Analytics Workspace. Finally, Azure Monitor alerts can be triggered based on a Kusto query to notify resources that there are SPN’s within the threshold for expiration.
2	Problem Statement
Azure services do not have a native feature to report on expiring App registrations. Without a solution in place to monitor and notify on expiration of these SPN’s solutions ranging from Custom Apps, and DevOps CI\CD Pipelines too orchestration engines like Azure Automation and Logic Apps, can and will cease to function without notice. 
•	Purpose: To provide an automated mechanism of calculating and ingesting the expiration dates into Log Analytics and automatically notify resources when expiration is within threshold.
•	Responsibility: Automation Engineers
•	Requisites: This solution consists of:
o	1 Runbook consisting of the PowerShell script in this document. 
o	2 Automation Variables containing the Log Analytics Workspace ID and the Log Analytics Primary Key.
o	1 SPN in the monitored cloud environment with Global Reader role.
3	Solution Design
This document will not go over creating the runbook and scheduling its execution but does provide the source code and how to setup the requisite assets.
3.1	Solution Design Architecture
 


3.2	AA Assets
3.2.1	AppRegistrationMonitor Credential
The App Registration Monitor is a SPN or App Registration that is created in the Azure Active Directory (AAD) tenant to be monitored. The SPN must have Global Reader rights in order to query all App Registrations and their property fields.
1.	From the desired AAD resource navigate to App Registrations ->New Registration -> In the Name: AppRegistrationMonitor
Account Types: Accounts in this organizational directory only
Redirect URL: Blank
Click Register
 

2.	Once the account has been created you will be redirected to the account Overview pane. Copy the value for the Application (client) ID to a notepad. 
 
3.	Navigate to Certificates & Secrets -> +New Client Secret
Description: Optional
Expires: 1 year
Click Add
Before navigating away Copy the Value to Notepad.
 
4.	Navigate to Azure Active Directory -> Roles and Administrators -> Global Reader   -> Add Assignments. Select the AppRegistrationMonitor account and click ok.
5.	Navigate to the Azure Automation Account -> Credentials -> Add a Credential.
Name: AppRegistrationMonitor
Description: Optional
User name: Paste the Application Client ID from step 2
Password: Paste the Secret Value from Step 3
Confirm Password: Paste the Secret Value from Step 3
Click Create
3.2.2	LogAnalyticsPrimaryKey
The Log Analytics Primary key is an Azure Automation variable that can be encrypted to prevent unauthorized disclosure.
To obtain the key, navigate to the Log Analytics Workspace -> Agents Management and copy the Primary Key field.
 
Once you have the key, return to the Azure Automation Account -> Variables -> + Add Variable.
•	Name: LogAnalyticsPrimaryKey
•	Description: Optional
•	Type: String
•	Value: Paste the key
•	Encrypted: Yes
Click Create
 

3.2.3	LogAnalyticsWorkspaceID
The Log Analytics Workspace ID is an Azure Automation variable that can be encrypted to prevent unauthorized disclosure.
To obtain the key, navigate to the Log Analytics Workspace -> Agents Management and copy the WorkspaceID field.
 
Once you have the key, return to the Azure Automation Account -> Variables -> + Add Variable.
•	Name: LogAnalyticsWorkspaceID
•	Description: Optional
•	Type: String
•	Value: Paste the key
•	Encrypted: Optional
Click Create
 
3.2.4	MonitoredTenantID
The Tenant ID for the cloud environment that is going to be monitored is an Azure Automation variable that can be encrypted to prevent unauthorized disclosure.
To obtain the key, navigate to the AppRegistrationMonitor SPN in Azure Active Directory on the Overview page you will find the Directory (tenant) ID  Copy the value.
Once you have the ID, return to the Azure Automation Account -> Variables -> + Add Variable.
•	Name: MonitoredTenantID
•	Description: Optional
•	Type: String
•	Value: Paste the key
•	Encrypted: Optional
Click Create
 
3.3	Azure Monitor Alert
To create the Azure monitor alert rule, navigate to Monitor -> Alerts -> New alert rule.
1.	Under Scope select the Log Analytics Workspace as the resource
2.	For Condition select Custom Log Search, past the Kusto query below into the search query box.
AppRegistrationExpiration_CL 
| where DaysToExpiration_d <= 30 //Change this value to the expiration threshold
| project TimeGenerated, DisplayName_s, ApplicationId_Guid_g, Type_s, StartDate_value_t, EndDate_value_t, Status_s, DaysToExpiration_d

•	Input a 0 to the threshold Value box.
•	And change the evaluation to 1440 and 1440 for a daily run.
•	Click Done
 
3.	Select and action group for email notification. If you do not already have one click Create action Group and follow the prompts. Fill out the Basic and Notifications Tabs.
 
 
4.	Under Customize Actions click Email Subject
Subject Line: NoReply: WARNING:: AppRegistrations Expiring
5.	Alert Rule Details:
Alert Rule Name: AppRegistrationsExpiring Notifications
Description: Optional
Save Alert rule to resource group: Select Log Analytics Workspace RG
Severity: Warning Sev 1
Enable alert rule upon creation: Checked
Suppress alert: not checked.
Create alert rule


4	Review and Validation 
4.1	Scripts
Script Title	Script Content
Get-AppregistrationExpiration.ps1	

Function _SendToLogAnalytics{
    Param(
        [string]$customerId,
        [string]$sharedKey,
        [string]$logs,
        [string]$logType,
        [string]$timeStampField
    )
        # Generate the body for the Invoke-WebRequest
        $body = ([System.Text.Encoding]::UTF8.GetBytes($Logs))
        $method = "POST"
        $contentType = "application/json"
        $resource = "/api/logs"
        $rfc1123date = [DateTime]::UtcNow.ToString("r")
        $contentLength = $body.Length

        #Create the encoded hash to be used in the authorization signature
        $xHeaders = "x-ms-date:" + $rfc1123date
        $stringToHash = $method + "`n" + $contentLength + "`n" + $contentType + "`n" + $xHeaders + "`n" + $resource
        $bytesToHash = [Text.Encoding]::UTF8.GetBytes($stringToHash)
        $keyBytes = [Convert]::FromBase64String($sharedKey)
        $sha256 = New-Object System.Security.Cryptography.HMACSHA256
        $sha256.Key = $keyBytes
        $calculatedHash = $sha256.ComputeHash($bytesToHash)
        $encodedHash = [Convert]::ToBase64String($calculatedHash)
        $authorization = 'SharedKey {0}:{1}' -f $customerId,$encodedHash

        # Create the uri for the data insertion endpoint for the Log Analytics workspace
        $uri = "https://" + $customerId + ".ods.opinsights.azure.us" + $resource + "?api-version=2016-04-01"

        # Create the headers to be used in the Invoke-WebRequest
        $headers = @{
            "Authorization" = $authorization;
            "Log-Type" = $logType;
            "x-ms-date" = $rfc1123date;
            "time-generated-field" = $timeStampField;
        }
        
        # Try to send the logs to the Log Analytics workspace
        Try{
            $response = Invoke-WebRequest `
            -Uri $uri `
            -Method $method `
            -ContentType $contentType `
            -Headers $headers `
            -Body $body `
            -UseBasicParsing `
            -ErrorAction stop
        }
        # Catch any exceptions and write them to the output 
        Catch{
            Write-Error "$($_.Exception)"
            throw "$($_.Exception)" 
        }
        # Return the status code of the web request response
        return $response
}


#### End Function Declaration Section ##############################################################

####Connect to the O365 Tenant using AutomationCredential###########################################
####Change the Azure Automation Credential Name on line 61
####Change the Tenant ID on line 68
Try{
    $credentials = Get-AutomationPSCredential -Name #"<CredentialName>" -ErrorAction Stop
} catch {
    write-error "Unable to find AutomationPSCredential"
    throw "Unable to find AutomationPSCredential"
}

Try {
    Connect-AzAccount -ServicePrincipal -Credential $credentials -Tenant #'<Tenant ID>'
} catch {
    write-error "$($_.Exception)"
    throw "$($_.Exception)"
}
Write-output 'Gathering necessary information...'

$applications = Get-AzADApplication
$servicePrincipals = Get-AzADServicePrincipal
$timeStamp = Get-Date -format o


$appWithCredentials = @()
$appWithCredentials += $applications | Sort-Object -Property DisplayName | % {
    $application = $_
    $sp = $servicePrincipals | ? ApplicationId -eq $application.ApplicationId
    Write-Verbose ('Fetching information for application {0}' -f $application.DisplayName)
    $application | Get-AzADAppCredential -ErrorAction SilentlyContinue | Select-Object `
    -Property @{Name='DisplayName'; Expression={$application.DisplayName}}, `
    @{Name='ObjectId'; Expression={$application.Id}}, `
    @{Name='ApplicationId'; Expression={$application.ApplicationId}}, `
    @{Name='KeyId'; Expression={$_.KeyId}}, `
    @{Name='Type'; Expression={$_.Type}},`
    @{Name='StartDate'; Expression={$_.StartDate -as [datetime]}},`
    @{Name='EndDate'; Expression={$_.EndDate -as [datetime]}}
  }

Write-output 'Validating expiration data...'
$today = (Get-Date).ToUniversalTime()
$appWithCredentials | Sort-Object EndDate | % {
        if($_.EndDate -lt $today) {
            $days= ($_.EndDate-$Today).Days
            $_ | Add-Member -MemberType NoteProperty -Name 'Status' -Value 'Expired'
            $_ | Add-Member -MemberType NoteProperty -Name 'TimeStamp' -Value "$timestamp"
            $_ | Add-Member -MemberType NoteProperty -Name 'DaysToExpiration' -Value $days
        }  else {
            $days= ($_.EndDate-$Today).Days
            $_ | Add-Member -MemberType NoteProperty -Name 'Status' -Value 'Valid'
            $_ | Add-Member -MemberType NoteProperty -Name 'TimeStamp' -Value "$timestamp"
            $_ | Add-Member -MemberType NoteProperty -Name 'DaysToExpiration' -Value $days
        }
}



$audit = $appWithCredentials | convertto-json
$customerId= Get-AutomationVariable -Name 'LogAnalyticsWorkspaceID'
$sharedKey= Get-AutomationVariable -Name 'LogAnalyticsPrimaryKey'

_SendToLogAnalytics -CustomerId $customerId `
                        -SharedKey $sharedKey `
                        -Logs $Audit `
                        -LogType "ServicePrincipalExpiration" `
                        -TimeStampField "TimeStamp"
Write-Output 'Done.'
 




# Get-AppRegistrationExpiration

## Overview
Solution was designed for the purpose of providing the ability to monitor and notify in the event of App Registration\Service Principal Name (SPN) secret key or certificate coming within the threshold of expiring. The solution is designed to be cross tenant and requires an App Registration\SPN in the desired environment with Global Reader rights. Utilizing Azure Automation (AA) and AA resources like Variables and Credentials our runbook pulls an array of SPN’s from the environment and calculates the time until expiration before using our custom function to send the data to a Log Analytics Workspace. Finally Azure Monitor alerts can be triggered based on a Kusto query to notify resources that there are SPN’s within the threshold for expiration.




Solution is designed for use in Azure Automtion and require a Azure Automation Credential with rights in the desired tenant. It will also require two Azure Automation Variable Assets for the Log Analytics Workspace:

'LogAnalyticsWorkspaceID'
'LogAnalyticsPrimaryKey'

I have tested this solution using Global Reader but more granular Graph permissions could and should be used.

Line 61 Requires you to change #"<CredentialName>" with the name of the Azure Automation Credential Asset within double quotes "".
  
Line 68 Requires you to change #'<Tenant ID>' with the tenant ID for the desired tenant within single quotes ''
  
The script will write the logs to the Log Analytics workspace, and a Azure Monitor Alert can be used with the kusto query outlined in the snippet to create notifications with the expiration window is within x days.


# More detailed Documentaiton Coming Soon
