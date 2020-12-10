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

Try{
    $credentials = Get-AutomationPSCredential -Name "AppRegistrationMonitor" -ErrorAction Stop
} catch {
    write-error "Unable to find AutomationPSCredential"
    throw "Unable to find AutomationPSCredential"
}

Try {
    $tenantID= Get-AutomationVariable -Name 'MonitoredTeantID'
    Connect-AzAccount -ServicePrincipal -Credential $credentials -Tenant $tenantID
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
                        -LogType "AppRegistrationExpiration" `
                        -TimeStampField "TimeStamp"
Write-Output 'Done.'
