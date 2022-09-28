
$projectName = Read-Host -Prompt "Enter Project Name" # Name used to generate for Azure resources
$location = Read-Host -Prompt "Enter a location, i.e. (centralus)"
$companyName = Read-Host -Prompt "Enter Company Name"
$env = Read-Host -Prompt "Enter environment"

$resourceGroupName = "rg-" + $projectName
$storageAccountName = "st" + $projectName + $companyName + $env + $location
$containerName = "templates"

$mainTemplateURL = "https://raw.githubusercontent.com/mafiaboy1994/newActiveDirectoryDomain-ha-2-dc-zones/main/azuredeploy.json"
$configureADBDC = "https://raw.githubusercontent.com/mafiaboy1994/newActiveDirectoryDomain-ha-2-dc-zones/main/configureADBDC.json"
$configureNIC = "https://raw.githubusercontent.com/mafiaboy1994/newActiveDirectoryDomain-ha-2-dc-zones/main/nic.json"
$configureVNET = "https://raw.githubusercontent.com/mafiaboy1994/newActiveDirectoryDomain-ha-2-dc-zones/main/vnet.json"

$mainFileName = "azuredeploy.json" # File name used for downloading and uploading the main template.Add-PSSnapin
$ADBDCFileName = "configureADBDC.json"
$NICFileName = "nic.json"
$VNETFileName = "vnet.json"

#Download templates
Invoke-WebRequest -Uri $mainTemplateURL -OutFile "$home/$mainFileName"
Invoke-WebRequest -Uri $configureADBDC -OutFile "$home/$ADBDCFileName"
Invoke-WebRequest -Uri $configureNIC -OutFile "$home/$NICFileName"
Invoke-WebRequest -Uri $configureVNET -OutFile "$home/$VNETFileName"

#Storage Group RG
New-AzResourceGroup -Name $resourceGroupName -Location $location

#Storage Account
$storageAccount = New-AzStorageAccount `
-ResourceGroupName $resourceGroupName `
-Name $storageAccountName `
-Location $location `
-SkuName "Standard_GRS"

$context = $storageAccount.Context

#Create a container
New-AzStorageContainer -Name $containerName -Context $context -Permission Container

#Upload Templates
Set-AzStorageBlobContent `
-Container $containerName `
-File "$home/$mainFileName" `
-Blob $mainFileName `
-Context $context

Set-AzStorageBlobContent `
-Container $containerName `
-File "$home/$ADBDCFileName" `
-Blob $ADBDCFileName `
-Context $context

Set-AzStorageBlobContent `
-Container $containerName `
-File "$home/$NICFileName" `
-Blob $NICFileName `
-Context $context

Set-AzStorageBlobContent `
-Container $containerName `
-File "$home/$VNETFileName" `
-Blob $VNETFileName `
-Context $context

Write-Host "Press [ENTER] to continue....."


$key = (Get-AzStorageAccountKey -ResourceGroupName $resourceGroupName -Name $storageAccountName).Value[0]

$mainTemplateUri = $context.BlobEndPoint + "$containerName/azuredeploy.json"
$sasToken = New-AzStorageContainerSASToken `
-Context $context `
-Container $containerName `
-Permission r `
-ExpiryTime (Get-Date).AddHours(2.0)

$newSas = $sasToken.substring(1)

New-AzSubscriptionDeployment `
-Name DeployMassTemplate `
-TemplateUri $mainTemplateUri `
-QueryString $newSas `
-Verbose

Write-Host "Press [ENTER] to continue....."
