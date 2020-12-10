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
