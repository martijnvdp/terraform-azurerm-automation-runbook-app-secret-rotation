param
(
    [Parameter (Mandatory = $false)]
    [object] $WebhookData,
    $clientSecretDisplayName = "created_by_az_aa_client_secret_rotation",
    $deleteClientSecret,
    [int]$keepExistingClientSecrets = 1,
    $eventType = "manual",
    $secretName,
    $vaultName
)


function remove-passwordCredentials {
    param
    (
        $appID,
        $passwordCredentials,
        [int]$keepExistingClientSecrets = 1
    )

    $passwordCount = $($passwordCredentials | Measure-Object).count
    Write-Output "[info] $($passwordCount ?? 0) existing secret(s) found."
    if ($passwordCount -ge 2) {
        Write-Output "[info] removing $($passwordCount - $keepExistingClientSecrets) existing secret(s)"
        $cleanupExistingCredentials = $passwordCredentials |  Sort-Object -Property EndDateTime -Descending | Select-Object -last ($passwordCount - $keepExistingClientSecrets)
        foreach ($credential in $cleanupExistingCredentials) {
            Remove-MgApplicationPassword -ApplicationId $appID -KeyId $credential.KeyId
        }
    }
}

function set-password {
    param (
        $appID,
        $clientSecretDisplayName,
        [int]$expirationInDays,
        $secretName,
        $vaultName
    )

    $Expires = (Get-Date).AddDays($expirationInDays)

    $passwordCred = @{
        displayName = $clientSecretDisplayName
        endDateTime = $Expires
    }
    $newPassword = Add-MgApplicationPassword -ApplicationId $appID -PasswordCredential $passwordCred
    Write-Output "[info] New client secret created for entra id application"
    $secretSecureString = ConvertTo-SecureString -String $newPassword.SecretText -AsPlainText -Force
    $existingSecret = Get-AzKeyVaultSecret -VaultName $vaultName -Name $secretName
    $result = Set-AzKeyVaultSecret -VaultName $vaultName -Name $secretName -ContentType "password" -SecretValue $secretSecureString -Expires $Expires -Tag $existingSecret.Tags
    Write-Output "[info] New client secret stored in key vault: $vaultName item $secretName at $($result.created)"
}

function get-daysLeft {
    param (
        $endDateTime
    )
    return ($endDateTime - (Get-Date)).Days
}

function add-ipToKeyvaultRule {
    param (
        $pubIpSource = "ipinfo.io/ip",
        $resourceGroupName,
        $vaultName
    )

    $ipAddress = (Invoke-WebRequest -uri $PubIPSource -UseBasicParsing).content.TrimEnd()
    if ($ipAddress) {
        Add-AzKeyVaultNetworkRule -VaultName $vaultName -ResourceGroupName $resourceGroupName -IpAddressRange $ipAddress
        return $ipAddress
    }
    else {
        Write-Error "[error] Failed to update keyvault network rule"
    }
}

function remove-ipFromKeyVaultRule {
    param (
        $ipAddress,
        $resourceGroupName,
        $vaultName
    )

    if ($ipAddress) {
        remove-AzKeyVaultNetworkRule -VaultName $vaultName -ResourceGroupName $resourceGroupName -IpAddressRange "$ipAddress/32"
        Write-Output "[info] IP address $ipAddress removed from the allowed list of the firewall."
    }
    else {
        Write-Error "[error] Failed to remove ip from the keyvault network rule"
    }
}

## start main function code ##
$ErrorActionPreference = "Stop"

if ($WebhookData) {
    $inputEvent = $WebhookData.RequestBody | ConvertFrom-Json
    $eventType = $inputEvent.eventType
    $objectType = $inputEvent.data.ObjectType
    $secretEXP = $inputEvent.data.EXP
    $secretName = $inputEvent.data.ObjectName
    $vaultName = $inputEvent.data.VaultName
}

# exit when not trigered from azure event grid or no webhook data found
if (!$WebhookData -and $eventType -ne "manual") {
    Write-Output "[info] no webdata found and trigered by webhook, exiting"
    return
}

if ($eventType -eq "manual" -and !$vaultName -or !$secretName) {
    Write-Output "[info] vault and secret name should be filled in when trigered manually"
    return
}

if ($eventType -eq "Microsoft.KeyVault.SecretNewVersionCreated" -and $secretEXP) {
    $expirationDate = [System.DateTimeOffset]::FromUnixTimeSeconds($secretEXP).datetime
    $daysLeft = ($expirationDate - (Get-Date).Date).Days
    if ($daysLeft -ge 31 ) {
        Write-Output "[info] skip secret from new secret version created event that already has an expiration date with $daysLeft remaining"
        return
    }
}

if ($eventType -match "Microsoft.KeyVault.SecretExpired|Microsoft.KeyVault.SecretNearExpiry|Microsoft.KeyVault.SecretNewVersionCreated|manual") {

    if ($objectType -ne "Secret" -and $eventType -ne "manual") {
        Write-Output "[info] Object type in webhook event data is not a secret"
        return
    }
    # login with managed service principal
    Connect-AzAccount -Identity
    Connect-MgGraph -Identity -NoWelcome
    $vault = $(Get-AzKeyVault -VaultName $vaultName)

    if (!$vault) {
        Write-Output "[info] Keyvault: $vaultName not found or rotation not enabled with tag: az_aa_client_secret_rotation.enabled"
        return
    }
    $publicIP = add-ipToKeyvaultRule -vaultName $vault.VaultName -resourceGroupName $vault.ResourceGroupName
    Write-Output "[info] IP address $publicIP added to the allowed list of the firewall rules for vault: $($vault.VaultName)."
    $secret = Get-AzKeyVaultSecret -SecretName $secretName -VaultName $vault.VaultName | Where-Object { $_.Tags -and $_.Tags["az_aa_client_secret_rotation.enabled"] -eq "true" -and $_.Tags["az_aa_client_secret_rotation.app_name"] }

    if (!$secret) {
        Write-Output "[info] Vault secret with name $($secretName) not found in $($vault.VaultName) or rotation not enabled with tag: az_aa_client_secret_rotation.enabled"
        return
    }
    # get settings from tags
    $appName = $secret.tags["az_aa_client_secret_rotation.app_name"]

    if (!$appName) {
        Write-Output "[info] Application not set in tag: az_aa_client_secret_rotation.app_name"
        return
    }
    $deleteClientSecret = $( $deleteClientSecret ?? ($secret.tags["az_aa_client_secret_rotation.delete_client_secret"]))
    if ($secret.tags["az_aa_client_secret_rotation.expiration_in_days"]) { $expirationInDays = $secret.tags["az_aa_client_secret_rotation.expiration_in_days"] }
    if ($secret.tags["az_aa_client_secret_rotation.client_secret_display_name"]) { $clientSecretDisplayName = $secret.tags["az_aa_client_secret_rotation.client_secret_display_name"] }
    Write-Output "[info] Processing: $($secret.name) for application: $appName"
    $app = Get-MgApplication -Search "DisplayName:$appName" -ConsistencyLevel "eventual"

    if (!$app.Id ) {
        Write-Error "[error] Application: $appName not found for $($secret.name)"
        return
    }
    # get the most recent credential
    $passwordCredentials = $app.passwordCredentials | Where-Object { $_.DisplayName -like "$clientSecretDisplayName*" }
    $passwordCredential = $passwordCredentials | Sort-Object -Property EndDateTime -Descending | Select-Object -First 1

    # if event is secret expired and existing client secret found
    if (($eventType -match "Microsoft.KeyVault.SecretExpired|Microsoft.KeyVault.SecretNearExpiry|manual") -and (!$deleteClientSecret)) {
        if ($passwordCredential) {
            $daysLeft = get-daysLeft -endDateTime $passwordCredential.EndDateTime
            Write-Output "[info] Starting rotate client secret for $appName, $($passwordCredential.displayname) has $daysLeft before expiration."
            # cleanup existing secrets
            remove-passwordCredentials -appID $app.Id -passwordCredentials $passwordCredentials -keepExistingClientSecrets $keepExistingClientSecrets
        }
        Write-Output "[info] Creating new secret with display name $clientSecretDisplayName for $appName"
        set-password -clientSecretDisplayName $clientSecretDisplayName -appID $app.Id -expirationInDays $expirationInDays -vaultName $vault.VaultName -secretName $secret.name -clientAPPID $app.AppId
        Write-Output "[info] Secret $clientSecretDisplayName for $appName rotated and stored in vault $vaultname"
        # remove automation ip from the keyvault allowed list
        remove-ipFromKeyVaultRule -ipAddress $publicIP -vaultName $vault.VaultName -resourceGroupName $vault.ResourceGroupName
        return
    }

    # if event is SecretNewVersionCreated
    if (($eventType -match "Microsoft.KeyVault.SecretNewVersionCreated") -and (!$deleteClientSecret)) {
        Write-Output "[info] Start creating new secret: $clientSecretDisplayName with $expirationInDays expiration.(triggered by event SecretNewVersionCreated)"
        remove-passwordCredentials -appID $app.Id -passwordCredentials $passwordCredentials -keepExistingClientSecrets $keepExistingClientSecrets
        set-password -clientSecretDisplayName $clientSecretDisplayName -appID $app.Id -expirationInDays $expirationInDays -vaultName $vault.VaultName -secretName $secret.name -clientAPPID $app.AppId
        # remove automation ip from the keyvault allowed list
        remove-ipFromKeyVaultRule -ipAddress $publicIP -vaultName $vault.VaultName -resourceGroupName $vault.ResourceGroupName
        return
    }

    # if delete client secret option is set to true
    if ($deleteClientSecret -and $passwordCredential) {
        Write-Output "[info] Cleanup client secrets: $clientSecretDisplayName for $appName, kv secret has tag: az_aa_client_secret_rotation.delete_client_secret set to true"
        remove-passwordCredentials -appID $app.Id -passwordCredentials $passwordCredentials -keepExistingClientSecrets $keepExistingClientSecrets
        remove-ipFromKeyVaultRule -ipAddress $publicIP -vaultName $vault.VaultName -resourceGroupName $vault.ResourceGroupName
        return
    }
    # remove automation ip from the keyvault allowed list
    remove-ipFromKeyVaultRule -ipAddress $publicIP -vaultName $vault.VaultName -resourceGroupName $vault.ResourceGroupName
}
