################ Azure login params ###################
$ServicePrincipalCertificateThumbprint = ''
$TenantId = '' #This is AAD Tenant Id where the below app registration is created, not Subscription Id
$ApplicationId = '' #THis is the application registration id sometimes called clientId. Make sure this app registration has permission to send message.

############### PoC related params ####################
$resourceGroupName = "" # RG of Service bus
$namespace = '' #just name of service bus without host name decorations.
$queueName = ''

$messageToSend = "My message at $(get-date)" #play with this.

#######################################################
# One time install
$serviceBusInstalled = Get-InstalledModule Az.ServiceBus

if( ! $serviceBusInstalled) {
    Install-Module Az.ServiceBus -AllowClobber
} 
else{
    Write-Host "Az.ServiceBus already present" -ForegroundColor Yellow
}
# Connect using service principal and validations

# If running from Linux use certificate path https://docs.microsoft.com/en-us/powershell/module/az.accounts/connect-azaccount?view=azps-6.4.0#example-9--connect-using-certificate-file
Connect-AzAccount -CertificateThumbprint $ServicePrincipalCertificateThumbprint -SendCertificateChain -ApplicationId $ApplicationId -Tenant $TenantId -ServicePrincipal

$queueInfo=Get-AzServiceBusQueue -ResourceGroupName $resourceGroupName -Namespace $namespace -QueueName $queueName
if(!$queueInfo){
    Write-Host "Queue with name $queueName not found in service bus namespace $namespace" -ForegroundColor Red
}
else{
    Write-Host "Queue found. Emitting queue info" -ForegroundColor Green
    $queueInfo
}
############## Send Message ############################

$accessToken = Get-AzAccessToken -ResourceUrl https://servicebus.azure.net/
#https://docs.microsoft.com/en-us/rest/api/servicebus/send-message-to-queue
$headers = @{ "Authorization" = "$($accessToken.Token)"; "Content-Type" = "application/atom+xml;type=entry;charset=utf-8" }
$uri = "https://$namespace.servicebus.windows.net/$queueName/messages"
"Sending request to $uri"
$result = Invoke-WebRequest -Uri $uri -Headers $headers -Method Post -Body $messageToSend

"$($result.StatusCode) - $($result.StatusDescription) // 201 means the message queued"

############## Receive and delete ######################

#https://docs.microsoft.com/en-us/rest/api/servicebus/receive-and-delete-message-destructive-read
$uri = "https://$namespace.servicebus.windows.net/$queueName/messages/head?timeout=60"
$result = Invoke-WebRequest -Uri $uri -Headers $headers -Method Delete
if ($result.StatusCode -eq 200) {
    Write-Host "Dequeued message with deletion - content:$($result.Content)" -ForegroundColor Green
}
elseif ($result.StatusCode -eq 204){
    Write-Host "No Message found" -ForegroundColor Yellow
}
