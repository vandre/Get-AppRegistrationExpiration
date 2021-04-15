AppRegistrationExpiration_CL 
| summarize arg_max(TimeGenerated,*) by ApplicationId_Guid_g
| where DaysToExpiration_d <= 50 //Change this value to the expiration threshold 
| where TimeGenerated > ago(1d)
| project TimeGenerated, DisplayName_s, ApplicationId_Guid_g, Type_s, StartDate_value_t, EndDate_value_t, Status_s, DaysToExpiration_d
