# 1	Overview
Solution was designed for the purpose of providing the ability to monitor and notify in the event of App Registration\Service Principal Name (SPN) secret key or certificate coming within the threshold of expiring. The solution is designed to be cross tenant and requires an App Registration\SPN in the desired environment with Global Reader rights. Utilizing Azure Automation (AA) and AA resources like Variables and Credentials our runbook pulls an array of SPN’s from the environment and calculates the time until expiration before using our custom function to send the data to a Log Analytics Workspace. Finally, Azure Monitor alerts can be triggered based on a Kusto query to notify resources that there are SPN’s within the threshold for expiration.
# 2	Problem Statement
Azure services do not have a native feature to report on expiring App registrations. Without a solution in place to monitor and notify on expiration of these SPN’s solutions ranging from Custom Apps, and DevOps CI\CD Pipelines too orchestration engines like Azure Automation and Logic Apps, can and will cease to function without notice. 
-	**Purpose:** To provide an automated mechanism of calculating and ingesting the expiration dates into Log Analytics and automatically notify resources when expiration is within threshold.
-	**Responsibility:** Automation Engineers
-	**Requisites:** This solution consists of:
     -	1 Runbook consisting of the PowerShell script in this document. 
     -	2 Automation Variables containing the Log Analytics Workspace ID and the Log Analytics Primary Key.
     -	1 SPN in the monitored cloud environment with Global Reader role.
# 3	Solution Design
This document will not go over creating the runbook and scheduling its execution but does provide the source code and how to setup the requisite assets.
## 3.1 Solution Architecture
![](https://github.com/Cj-Scott/Get-AppRegistrationExpiration/blob/main/Images/Pic1.png)
## 3.2	AA Assets
## 3.2.1	AppRegistrationMonitor Credential
The App Registration Monitor is a SPN or App Registration that is created in the Azure Active Directory (AAD) tenant to be monitored. The SPN must have Global Reader rights in order to query all App Registrations and their property fields.
### 1.	From the desired AAD resource navigate to App Registrations ->New Registration -> In the Name: AppRegistrationMonitor
- **Account Types:** Accounts in this organizational directory only
- **Redirect URL:** Blank
- **Click Register**

![](https://github.com/Cj-Scott/Get-AppRegistrationExpiration/blob/main/Images/Pic2.png) 

### 2.	Once the account has been created you will be redirected to the account Overview pane. Copy the value for the Application (client) ID to a notepad. 

![](https://github.com/Cj-Scott/Get-AppRegistrationExpiration/blob/main/Images/Pic3.png)

### 3.	Navigate to Certificates & Secrets -> +New Client Secret
- **Description:** Optional
- **Expires**: 1 year
- **Click Add**
- **Before navigating away Copy the Value to Notepad.**

![](https://github.com/Cj-Scott/Get-AppRegistrationExpiration/blob/main/Images/Pic4.png)


### 4.	Navigate to Azure Active Directory -> Roles and Administrators -> Global Reader   -> Add Assignments. Select the AppRegistrationMonitor account and click ok.
### 5.	Navigate to the Azure Automation Account -> Credentials -> Add a Credential.
- **Name:** AppRegistrationMonitor
- **Description:** Optional
- **User name:** Paste the Application Client ID from step 2
- **Password:** Paste the Secret Value from Step 3
- **Confirm Password:** Paste the Secret Value from Step 3
- **Click Create**
### 3.2.2	LogAnalyticsPrimaryKey
The Log Analytics Primary key is an Azure Automation variable that can be encrypted to prevent unauthorized disclosure.
To obtain the key, navigate to the Log Analytics Workspace -> Agents Management and copy the Primary Key field.

![](https://github.com/Cj-Scott/Get-AppRegistrationExpiration/blob/main/Images/Pic5.png)

Once you have the key, return to the Azure Automation Account -> Variables -> + Add Variable.
- **Name:** LogAnalyticsPrimaryKey
- **Description:** Optional
- **Type:** String
- **Value:** Paste the key
- **Encrypted:** Yes
- **Click Create**
 
![](https://github.com/Cj-Scott/Get-AppRegistrationExpiration/blob/main/Images/Pic6.png)

### 3.2.3	LogAnalyticsWorkspaceID
The Log Analytics Workspace ID is an Azure Automation variable that can be encrypted to prevent unauthorized disclosure.
To obtain the key, navigate to the Log Analytics Workspace -> Agents Management and copy the WorkspaceID field.

![](https://github.com/Cj-Scott/Get-AppRegistrationExpiration/blob/main/Images/Pic7.png)

Once you have the key, return to the Azure Automation Account -> Variables -> + Add Variable.
- **Name:** LogAnalyticsWorkspaceID
- **Description:** Optional
- **Type:** String
- **Value:** Paste the key
- **Encrypted:** Optional
**Click Create**

![](https://github.com/Cj-Scott/Get-AppRegistrationExpiration/blob/main/Images/Pic8.png)

### 3.2.4	MonitoredTenantID
The Tenant ID for the cloud environment that is going to be monitored is an Azure Automation variable that can be encrypted to prevent unauthorized disclosure.
To obtain the key, navigate to the AppRegistrationMonitor SPN in Azure Active Directory on the Overview page you will find the Directory (tenant) ID  Copy the value.
Once you have the ID, return to the Azure Automation Account -> Variables -> + Add Variable.
- **Name:** MonitoredTenantID
- **Description:** Optional
- **Type**: String
- **Value:** Paste the key
- **Encrypted:** Optional
**Click Create**

![](https://github.com/Cj-Scott/Get-AppRegistrationExpiration/blob/main/Images/Pic9.png)

## 3.3	Azure Monitor Alert
To create the Azure monitor alert rule, navigate to Monitor -> Alerts -> New alert rule.
### 1.	Under Scope select the Log Analytics Workspace as the resource
### 2.	For Condition select Custom Log Search, past the Kusto query below into the search query box.
`AppRegistrationExpiration_CL 
| where DaysToExpiration_d <= 30 //Change this value to the expiration threshold
| project TimeGenerated, DisplayName_s, ApplicationId_Guid_g, Type_s, StartDate_value_t, EndDate_value_t, Status_s, DaysToExpiration_d`

-	Input a **0** to the threshold Value box.
-	And change the evaluation to **1440** and **1440** for a daily run.
-	**Click Done**

![](https://github.com/Cj-Scott/Get-AppRegistrationExpiration/blob/main/Images/Pic10.png)

### 3.	Select and action group for email notification. If you do not already have one click Create action Group and follow the prompts. Fill out the Basic and Notifications Tabs.
 
![](https://github.com/Cj-Scott/Get-AppRegistrationExpiration/blob/main/Images/Pic11.png)

### 4.	Under Customize Actions click Email Subject
- **Subject Line:** NoReply: WARNING:: AppRegistrations Expiring
### 5.	Alert Rule Details:
- **Alert Rule Name:** AppRegistrationsExpiring Notifications
- **Description:** Optional
- **Save Alert rule to resource group:** Select Log Analytics Workspace RG
- **Severity:** Warning Sev 1
- **Enable alert rule upon creation:** Checked
- **Suppress alert:** not checked.
- **Create alert rule**

