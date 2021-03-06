# Active Directory preparation

Below are the steps, including many PowerShell commands to prepare an AD environment

1. Deploy Windows Server 2012 R2
1. Set hostname to your liking
1. Install AD services
1. Configure AD
1. Add self-signed certificate for AD's LDAPS to work
1. Populate sample containers, users & groups
1. Delegate control to appropriate users

****************************************

## 1. Deploy Windows Server 2012 R2

- Most Cloud providers will have this option
- On Google Cloud, they have a "one-click" option to deploy AD

## 2. Set hostname

## Change hostname, if needed, and restart

```
## this will restart the server
$new_hostname = "ad01"
Rename-Computer -NewName $new_hostname -Restart
```

****************************************

## Install AD

1. Open Powershell (right click and "open as Administrator)

2. Prepare your environment. Update these to your liking.

```
$domainname = "dev.hwxopsrv.com"
$domainnetbiosname = "DEV"
$password = "BadPass#1"
```

3. Install AD features & Configure AD. There are 2 options:
  1. Deploy AD without DNS (relying on /etc/hosts or a separate DNS)

Install-WindowsFeature AD-Domain-Services â€“IncludeManagementTools, rsat-adds -IncludeAllSubFeature"
```
Install-WindowsFeature AD-Domain-Services â€“IncludeManagementTools
Import-Module ADDSDeployment
$secure_string_pwd = convertto-securestring ${password} -asplaintext -force
Install-ADDSForest `
-DatabasePath "C:\Windows\NTDS" `
-DomainMode "Win2012R2" `
-DomainName ${domainname} `
-DomainNetbiosName ${domainnetbiosname} `
-ForestMode "Win2012R2" `
-InstallDns:$false `
-LogPath "C:\Windows\NTDS" `
-NoRebootOnCompletion:$false `
-SysvolPath "C:\Windows\SYSVOL" `
-SafeModeAdministratorPassword:$secure_string_pwd `
-Force:$true
```

   2. Or deploy AD with DNS

```
Install-WindowsFeature AD-Domain-Services â€“IncludeManagementTools
Import-Module ADDSDeployment
$secure_string_pwd = convertto-securestring ${password} -asplaintext -force
Install-ADDSForest `
-CreateDnsDelegation:$false `
-DatabasePath "C:\Windows\NTDS" `
-DomainMode "Win2012R2" `
-DomainName ${domainname} `
-DomainNetbiosName ${domainnetbiosname} `
-ForestMode "Win2012R2" `
-InstallDns:$true `
-LogPath "C:\Windows\NTDS" `
-NoRebootOnCompletion:$false `
-SysvolPath "C:\Windows\SYSVOL" `
-SafeModeAdministratorPassword:$secure_string_pwd `
-Force:$true
```

****************************************

## Add UPN suffixes

If the domain of your Hadoop nodes is different than your AD domain:
https://technet.microsoft.com/en-gb/library/cc772007.aspx


****************************************

## Enable LDAPS

There are several methods to enable SSL for LDAP (aka LDAPS).

a. Generate a self-signed certificate from your AD server, or other Windows Certificate Authority.
b. Use a certificate from a public respected certificate authority.
c. Generate a self-signed certificate from your own certificate authority.

### Instructions:

a. Generate a self-signed certificate from your AD server, or other Windows Certificate Authority.
  1. From PowerShell:

```
## Install & Configure Certificate Authority with defaults
Import-Module ServerManager
Get-WindowsFeature -Name AD-Certificate | Install-WindowsFeature -IncludeManagementTools
Install-AdcsCertificationAuthority

## Save Base64 Encoded CA certificate, as ad01.cer, to be deployed to all hosts which will use.
Get-ChildItem C:\Windows\system32\CertSrv\CertEnroll *.crt | Copy-Item -Destination 'c:\Users\All Users\Desktop\ad01.crt'
certutil -encode 'c:\Users\All Users\Desktop\ad01.crt' 'c:\Users\All Users\Desktop\ad01.cer'
```

  2. From UI:
  - On your Windows Server: [Install Active Directory Certificate Services](https://technet.microsoft.com/en-us/library/jj717285.aspx)
    - Ensure to configure as "Enterprise CA" not "Standalone CA".
    - Once it's installed:
      - Server Manager -> Tools -> Certificate Authority
      - Action -> Properties
      - General Tab -> View Certificate -> Details -> Copy to File
      - Choose the format: "Base-64 encoded X.509 (.CER)"
      - Save as 'activedirectory.cer' (or whatever you like)
      - Open with Notepad -> Copy Contents
      - This is your public CA to be distributed to all of your client hosts.
      - Reboot the Active Directory server for it to load the certificate.

2. See Active Directory documentation.

3. Generate a self-signed certificate however you like.
   - Many options for this. I prefer OpenSSL (run from wherever you like):

```
openssl genrsa -out ca.key 4096
openssl req -new -x509 -days 3650 -key ca.key -out ca.crt \
    -subj '/CN=lab.hortonworks.net/O=Hortonworks Testing/C=US'

openssl genrsa -out wildcard-lab-hortonworks-net.key 2048
openssl req -new -key wildcard-lab-hortonworks-net.key -out wildcard-lab-hortonworks-net.csr \
    -subj '/CN=*.lab.hortonworks.net/O=Hortonworks Testing/C=US'
openssl x509 -req -in wildcard-lab-hortonworks-net.csr -CA ca.crt -CAkey ca.key -CAcreateserial -out wildcard-lab-hortonworks-net.crt -days 3650

openssl pkcs12 -export -name "PEAP Certificate" -CSP 'Microsoft RSA SChannel Cryptographic Provider' -LMK -inkey wildcard-lab-hortonworks-net.key -in wildcard-lab-hortonworks-net.crt -certfile ca.crt  -out wildcard-lab-hortonworks-net.p12
```
   - Copy wildcard-lab-hortonworks-net.p12 to the Active Directory server
   - On your Active Directory server:
      - Run "mmc"
      - Open the "Certificates snap-in".
      - Expand the "Certificates" node under "Personal".
      - Select "All Tasks" -> "Import...", and import the the "p12".
      - Reboot the Active Directory server for it to load the certificate.

****************************************

## Configure AD OUs, Groups, Users, ...

```
$my_base = "DC=dev,DC=hwxopsrv,DC=com"
$my_domain = 'dev.hwxopsrv.com'
$my_groups = "hadoop-users","hadoop-admins","ldap-users","sre"

$AccountPassword = "BadPass#1" | ConvertTo-SecureString -AsPlainText -Force

NEW-ADOrganizationalUnit "Corp"
NEW-ADOrganizationalUnit "Users" -path "OU=Corp,$my_base"
NEW-ADOrganizationalUnit "People" -path "OU=Users,OU=Corp,$my_base"
NEW-ADOrganizationalUnit "Groups" -path "OU=Users,OU=Corp,$my_base"
NEW-ADOrganizationalUnit "Services" -path "OU=Users,OU=Corp,$my_base"
NEW-ADOrganizationalUnit "Computers" -path "OU=Corp,$my_base"
NEW-ADOrganizationalUnit "Hadoop" -path "OU=Computers,OU=Corp,$my_base"
NEW-ADOrganizationalUnit "Services" -path "OU=Corp,$my_base"
NEW-ADOrganizationalUnit "Hadoop" -path "OU=Services,OU=Corp,$my_base"

$UserCSV = @"
samAccountName,Name,ParentOU,Group
hadoop-admin,"hadoop-admin","OU=Services,OU=Users,OU=Corp,$my_base","hadoop-admins"
ldap-reader,"ldap-reader","OU=Services,OU=Users,OU=Corp,$my_base","ldap-users"
registersssd,"registersssd","OU=Services,OU=Users,OU=Corp,$my_base","ldap-users"
sroberts,"Sean Roberts","OU=People,OU=Users,OU=Corp,$my_base","hadoop-users"
awiebe,"Aaron Wiebe","OU=People,OU=Users,OU=Corp,$my_base","hadoop-users"
mmcdowell,"Matthew McDowell","OU=People,OU=Users,OU=Corp,$my_base","hadoop-users"
"@

Import-Module ActiveDirectory

$my_groups | ForEach-Object {
    NEW-ADGroup â€“name $_ â€“groupscope Global â€“path "OU=Groups,OU=Users,OU=Corp,$my_base";
}

$UserCSV > Users.csv
Import-Csv "Users.csv" | ForEach-Object {
    $userPrincinpal = $_."samAccountName" + "@${my_domain}"
    New-ADUser -Name $_.Name `
        -Path $_."ParentOU" `
        -SamAccountName  $_."samAccountName" `
        -UserPrincipalName  $userPrincinpal `
        -AccountPassword $AccountPassword `
        -ChangePasswordAtLogon $false  `
        -Enabled $true
    add-adgroupmember -identity $_."Group" -member (Get-ADUser $_."samAccountName")
    add-adgroupmember -identity "hadoop-users" -member (Get-ADUser $_."samAccountName")
}
```

1. Delegate OU permissions to `hadoopadmin` for `OU=Hadoop,OU=Services,OU=Corp` (right click HadoopServices > Delegate Control > Add > hadoopadmin > checknames > OK >  "Create, delete, and manage user accounts" > OK)


1. Give registersssd user permissions to join workstations to OU=Hadoop,OU=Computers,OU=Corp (needed to run 'adcli join' successfully)

```
# CorpUsers > Properties > Security > Advanced >
#    Add > 'Select a principal' > registersssd > Check names > Ok > Select below checkboxes > OK
#           Create Computer Objects
#           Delete Computer Objects
#    Add > 'Select a principal' > registersssd > Check names > Ok > Set 'Applies to' to: 'Descendant Computer Objects' > select below checkboxes > Ok > Apply
#           Read All Properties
#           Write All Properties
#           Read Permissions
#           Modify Permissions
#           Change Password
#           Reset Password
#           Validated write to DNS host name
#           Validated write to service principle name
```

For more details see: https://jonconwayuk.wordpress.com/2011/10/20/minimum-permissions-required-for-account-to-join-workstations-to-the-domain-during-deployment/

1. To test the LDAP connection from a Linux node
  ```
  sudo yum install openldap-clients
  ldapsearch -h ad01.dev.hwxopsrv.com -p 389 -D "ldap-reader@lab.hortonworks.net" -w BadPass#1 -b "OU=Users,OU=Corp,DC=net,DC=hwxopsrv,DC=com" "(&(objectclass=person)(sAMAccountName=hadoop-admin))"
  ```

