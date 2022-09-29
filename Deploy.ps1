
$projectName = Read-Host -Prompt "Enter Project Name" # Name used to generate for Azure resources
$location = Read-Host -Prompt "Enter a location, i.e. (centralus)"
$companyName = Read-Host -Prompt "Enter Company Name"
$env = Read-Host -Prompt "Enter environment"

$resourceGroupName = "rg-" + $projectName + $companyName + $env + $location
$storageAccountName = "st" + $projectName + $companyName + $env + $location
$containerName = "templates"

$mainTemplateURL = "https://raw.githubusercontent.com/mafiaboy1994/newActiveDirectoryDomain-ha-2-dc-zones/main/azuredeploy.json"
$mainTemplateParamsURL = "https://raw.githubusercontent.com/mafiaboy1994/newActiveDirectoryDomain-ha-2-dc-zones/main/azuredeploy.parameters.json"
$configureADBDC = "https://raw.githubusercontent.com/mafiaboy1994/newActiveDirectoryDomain-ha-2-dc-zones/main/nestedtemplates/configureADBDC.json"
$configureADBDCPS = "https://raw.githubusercontent.com/mafiaboy1994/newActiveDirectoryDomain-ha-2-dc-zones/main/DSC/ConfigureADBDC.ps1"
$configureADBDCZip = "https://github.com/mafiaboy1994/newActiveDirectoryDomain-ha-2-dc-zones/raw/main/DSC/ConfigureADBDC.ps1.zip"
$configureNIC = "https://raw.githubusercontent.com/mafiaboy1994/newActiveDirectoryDomain-ha-2-dc-zones/main/nestedtemplates/nic.json"
$configureVNET = "https://raw.githubusercontent.com/mafiaboy1994/newActiveDirectoryDomain-ha-2-dc-zones/main/nestedtemplates/vnet.json"
$prepareADBDCZip = "https://github.com/mafiaboy1994/newActiveDirectoryDomain-ha-2-dc-zones/raw/main/DSC/PrepareADBDC.ps1.zip"
$prepareADBDCPS = "https://raw.githubusercontent.com/mafiaboy1994/newActiveDirectoryDomain-ha-2-dc-zones/main/DSC/PrepareADBDC.ps1"
$createADPDCZip = "https://github.com/mafiaboy1994/newActiveDirectoryDomain-ha-2-dc-zones/raw/main/DSC/CreateADPDC.ps1.zip"
$createADPDCPS = "https://raw.githubusercontent.com/mafiaboy1994/newActiveDirectoryDomain-ha-2-dc-zones/main/DSC/CreateADPDC.ps1"



$mainFileName = "azuredeploy.json" # File name used for downloading and uploading the main template.Add-PSSnapin
$mainParamsFileName = ".\azuredeploy.parameters.json"
$ADBDCFileName = "configureADBDC.json"
$configureADBDCPSFileName = "ConfigureADBDC.ps1"
$configureADBDCZipFileName = "ConfigureADBDC.ps1.zip"
$NICFileName = "nic.json"
$VNETFileName = "vnet.json"
$prepareADBDCZipFileName = "PrepareADBDC.ps1.zip"
$prepareADBDCPSFileName = "PrepareADBDC.ps1"
$createADPDCZipFileName = "CreateADPDC.ps1.zip"
$createADPDCPSFileName = "CreateADPDC.ps1"

#Download templates
mkdir $home/nestedtemplates
mkdir $home/DSC
Invoke-WebRequest -Uri $mainTemplateURL -OutFile "$home/$mainFileName"
Invoke-WebRequest -Uri $mainTemplateParamsURL -OutFile "$home/$mainParamsFileName"
Invoke-WebRequest -Uri $configureADBDC -OutFile "$home/nestedtemplates/$ADBDCFileName"
Invoke-WebRequest -Uri $configureADBDCPS -OutFile "$home/DSC/$configureADBDCPSFileName"
Invoke-WebRequest -Uri $configureADBDCZip -OutFile "$home/DSC/$configureADBDCZipFileName"
Invoke-WebRequest -Uri $configureNIC -OutFile "$home/nestedtemplates/$NICFileName"
Invoke-WebRequest -Uri $configureVNET -OutFile "$home/nestedtemplates/$VNETFileName"
Invoke-WebRequest -Uri $prepareADBDCZip -OutFile "$home/DSC/$prepareADBDCZipFileName"
Invoke-WebRequest -Uri $prepareADBDCPS -OutFile "$home/DSC/$prepareADBDCPSFileName"
Invoke-WebRequest -Uri $createADPDCZip -OutFile "$home/DSC/$createADPDCZipFileName"
Invoke-WebRequest -Uri $createADPDCPS -OutFile "$home/DSC/$createADPDCPSFileName"

#Storage Group RG
New-AzResourceGroup -Name $resourceGroupName -Location $location

#Storage Account
$storageAccount = New-AzStorageAccount `
-ResourceGroupName $resourceGroupName `
-Name $storageAccountName `
-Location $location `
-SkuName "Standard_GRS"

$key = (Get-AzStorageAccountKey -ResourceGroupName $resourceGroupName -Name $storageAccountName).Value[0]
#$context = $storageAccount.Context
$context = New-AzStorageContext -StorageAccountName $storageAccountName -StorageAccountKey $key
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
-File "$home/$mainParamsFileName" `
-Blob $mainParamsFileName `
-Context $context

# Nested Templates Upload
Set-AzStorageBlobContent `
-Container $containerName `
-File "$home/nestedtemplates/$ADBDCFileName" `
-Blob "nestedtemplates/${ADBDCFileName}" `
-Context $context

Set-AzStorageBlobContent `
-Container $containerName `
-File "$home/nestedtemplates/$NICFileName" `
-Blob "nestedtemplates/${NICFileName}" `
-Context $context

Set-AzStorageBlobContent `
-Container $containerName `
-File "$home/nestedtemplates/$VNETFileName" `
-Blob "nestedtemplates/${VNETFileName}" `
-Context $context

# DSC Templates Upload

Set-AzStorageBlobContent `
-Container $containerName `
-File "$home/DSC/$configureADBDCPSFileName" `
-Blob "DSC/${configureADBDCPSFileName}" `
-Context $context

Set-AzStorageBlobContent `
-Container $containerName `
-File "$home/DSC/$configureADBDCZipFileName" `
-Blob "DSC/${configureADBDCZipFileName}" `
-Context $context

Set-AzStorageBlobContent `
-Container $containerName `
-File "$home/DSC/$prepareADBDCZipFileName" `
-Blob "DSC/${prepareADBDCZipFileName}" `
-Context $context

Set-AzStorageBlobContent `
-Container $containerName `
-File "$home/DSC/$prepareADBDCPSFileName" `
-Blob "DSC/${prepareADBDCPSFileName}" `
-Context $context

Set-AzStorageBlobContent `
-Container $containerName `
-File "$home/DSC/$createADPDCZipFileName" `
-Blob "DSC/${createADPDCZipFileName}" `
-Context $context

Set-AzStorageBlobContent `
-Container $containerName `
-File "$home/DSC/$createADPDCPSFileName" `
-Blob "DSC/${createADPDCPSFileName}" `
-Context $context






Write-Host "Press [ENTER] to continue....."



$mainTemplateUri = $context.BlobEndPoint + "$containerName/azuredeploy.json"
$mainTemplateParamsUri = $contex.BlobEndPoint + "$containerName/azuredeploy.parameters.json"
$sasToken = New-AzStorageContainerSASToken `
-Context $context `
-Container $containerName `
-Permission r `
-ExpiryTime (Get-Date).AddHours(2.0)

$newSas = $sasToken.substring(1)

New-AzResourceGroupDeployment `
-Name DeployMainTemplate `
-ResourceGroupName $resourceGroupName `
-TemplateUri $mainTemplateUri `
-TemplateParameterUri $mainTemplateParamsUri `
-QueryString $newSas `
-Verbose 


