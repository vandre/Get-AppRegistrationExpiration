# Get-AppRegistrationExpiration

Solution is designed for use in Azure Automtion and require a Azure Automation Credential with rights in the desired tenant. It will also require two Azure Automation Variable Assets for the Log Analytics Workspace:

'LogAnalyticsWorkspaceID'
'LogAnalyticsPrimaryKey'

I have tested this solution using Global Reader but more granular Graph permissions could and should be used.

Line 61 Requires you to change #"<CredentialName>" with the name of the Azure Automation Credential Asset within double quotes "".
  
Line 68 Requires you to change #'<Tenant ID>' with the tenant ID for the desired tenant within single quotes ''
  
The script will write the logs to the Log Analytics workspace, and a Azure Monitor Alert can be used with the kusto query outlined in the snippet to create notifications with the expiration window is within x days.


# More detailed Documentaiton Coming Soon
