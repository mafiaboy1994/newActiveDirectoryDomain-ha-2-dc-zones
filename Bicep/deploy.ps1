
$projectName = Read-Host -Prompt "Enter Project Name" # Name used to generate for Azure resources
$location = Read-Host -Prompt "Enter a location, i.e. (centralus)"
$companyName = Read-Host -Prompt "Enter Company Name"
$env = Read-Host -Prompt "Enter environment"
$product = Read-Host -Prompt "Products being used?"

$folderPaths = (
    "${home}/nestedTemplates",
    "${home}/DSC",
    "${home}/params"
)

$resourceGroupName = "rg-" + $projectName + "-" + $companyName + "-" + $product + "-" + $env + "-" + $location
$storageAccountName = "st" + $projectName.ToLower()  + $env
$containerName = "templates"

# Download Github raw files for upload to Storage Account

#$configureADBDCPS = "https://raw.githubusercontent.com/mafiaboy1994/newActiveDirectoryDomain-ha-2-dc-zones/main/DSC/ConfigureADBDC.ps1"
#$prepareADBDCPS = "https://raw.githubusercontent.com/mafiaboy1994/newActiveDirectoryDomain-ha-2-dc-zones/main/DSC/PrepareADBDC.ps1"
#$createADPDCPS = "https://raw.githubusercontent.com/mafiaboy1994/newActiveDirectoryDomain-ha-2-dc-zones/main/DSC/CreateADPDC.ps1"
#$mainTemplateURL = "https://raw.githubusercontent.com/mafiaboy1994/newActiveDirectoryDomain-ha-2-dc-zones/main/azuredeploy.json"
#$mainTemplateParamsURL = "https://raw.githubusercontent.com/mafiaboy1994/newActiveDirectoryDomain-ha-2-dc-zones/main/azuredeploy.parameters.json"
#$configureADBDCBicep = "https://raw.githubusercontent.com/mafiaboy1994/newActiveDirectoryDomain-ha-2-dc-zones/main/nestedtemplates/configureADBDC.json"

$configureADBDCZip = "https://github.com/mafiaboy1994/newActiveDirectoryDomain-ha-2-dc-zones/raw/main/Bicep/scripts/ConfigureADBDC.ps1.zip"
$prepareADBDCZip = "https://github.com/mafiaboy1994/newActiveDirectoryDomain-ha-2-dc-zones/raw/main/Bicep/scripts/PrepareADBDC.ps1.zip"
$createADPDCZip = "https://github.com/mafiaboy1994/newActiveDirectoryDomain-ha-2-dc-zones/raw/main/Bicep/scripts/CreateADPDC.ps1.zip"

#$mainFileName = "azuredeploy.json" # File name used for downloading and uploading the main template.Add-PSSnapin
#$mainParamsFileName = ".\azuredeploy.parameters.json"
#$ADBDCFileName = "configureADBDC.bicep"
#$configureADBDCPSFileName = "ConfigureADBDC.ps1"
$configureADBDCZipFileName = "ConfigureADBDC.ps1.zip"
$prepareADBDCZipFileName = "PrepareADBDC.ps1.zip"
#$prepareADBDCPSFileName = "PrepareADBDC.ps1"
$createADPDCZipFileName = "CreateADPDC.ps1.zip"
#$createADPDCPSFileName = "CreateADPDC.ps1"


# Creating required folders if not already setup in $home
foreach($paths in $folderPaths){
    if(Test-Path -Path $paths){
    }
    else{
        mkdir $paths > $null
    }
}

#Download templates
#Invoke-WebRequest -Uri $mainTemplateURL -OutFile "$home/$mainFileName"
#Invoke-WebRequest -Uri $mainTemplateParamsURL -OutFile "$home/$mainParamsFileName"
#Invoke-WebRequest -Uri $createADPDCPS -OutFile "$home/DSC/$createADPDCPSFileName"
#Invoke-WebRequest -Uri $nsgparams -OutFile "$home/params/$nsgparamsFileName"
#Invoke-WebRequest -Uri $configureADBDC -OutFile "$home/nestedtemplates/$ADBDCFileName"
#Invoke-WebRequest -Uri $configureADBDCPS -OutFile "$home/DSC/$configureADBDCPSFileName"
#Invoke-WebRequest -Uri $prepareADBDCPS -OutFile "$home/DSC/$prepareADBDCPSFileName"

#Invoke-WebRequest -Uri $configureADBDCBicep -OutFile "$home/$ADBDCFileName"
Invoke-WebRequest -Uri $configureADBDCZip -OutFile "$home/DSC/$configureADBDCZipFileName"
Invoke-WebRequest -Uri $prepareADBDCZip -OutFile "$home/DSC/$prepareADBDCZipFileName"
Invoke-WebRequest -Uri $createADPDCZip -OutFile "$home/DSC/$createADPDCZipFileName"


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

Write-Host "Press [ENTER] to continue....."

#Upload Templates
<#
Set-AzStorageBlobContent `
-Container $containerName `
-File "$home/$mainFileName" `
-Blob $mainFileName `
-Context $context -Force

Set-AzStorageBlobContent `
-Container $containerName `
-File "$home/$mainParamsFileName" `
-Blob $mainParamsFileName `
-Context $context -Force


# Nested Templates Upload
Set-AzStorageBlobContent `
-Container $containerName `
-File "$home/nestedtemplates/$ADBDCFileName" `
-Blob "nestedtemplates/${ADBDCFileName}" `
-Context $context -Force
#>
<#
Set-AzStorageBlobContent `
-Container $containerName `
-File "$home/nestedtemplates/$NICFileName" `
-Blob "nestedtemplates/${NICFileName}" `
-Context $context -Force

Set-AzStorageBlobContent `
-Container $containerName `
-File "$home/nestedtemplates/$VNETFileName" `
-Blob "nestedtemplates/${VNETFileName}" `
-Context $context -Force
#>

# DSC Templates Upload

<#
Set-AzStorageBlobContent `
-Container $containerName `
-File "$home/DSC/$configureADBDCPSFileName" `
-Blob "DSC/${configureADBDCPSFileName}" `
-Context $context -Force
#>

Set-AzStorageBlobContent `
-Container $containerName `
-File "$home/DSC/$configureADBDCZipFileName" `
-Blob "DSC/${configureADBDCZipFileName}" `
-Context $context -Force

Set-AzStorageBlobContent `
-Container $containerName `
-File "$home/DSC/$prepareADBDCZipFileName" `
-Blob "DSC/${prepareADBDCZipFileName}" `
-Context $context -Force

<#
Set-AzStorageBlobContent `
-Container $containerName `
-File "$home/DSC/$prepareADBDCPSFileName" `
-Blob "DSC/${prepareADBDCPSFileName}" `
-Context $context -Force
#>


Set-AzStorageBlobContent `
-Container $containerName `
-File "$home/DSC/$createADPDCZipFileName" `
-Blob "DSC/${createADPDCZipFileName}" `
-Context $context -Force

<#
Set-AzStorageBlobContent `
-Container $containerName `
-File "$home/DSC/$createADPDCPSFileName" `
-Blob "DSC/${createADPDCPSFileName}" `
-Context $context -Force


Set-AzStorageBlobContent `
-Container $containerName `
-File "$home/params/$nsgparamsFileName" `
-Blob "params/${nsgparamsFileName}" `
-Context $context -Force
#>



Write-Host "Press [ENTER] to continue....."


<#
$mainTemplateUri = $context.BlobEndPoint + "$containerName/azuredeploy.json"
$mainTemplateParamsUri = $contex.BlobEndPoint + "$containerName/azuredeploy.parameters.json"
$sasToken = New-AzStorageContainerSASToken `
-Context $context `
-Container $containerName `
-Permission r `
-ExpiryTime (Get-Date).AddHours(2.0)

$newSas = $sasToken.substring(1)
#>

New-AzResourceGroupDeployment `
-Name DeployMainTemplate `
-ResourceGroupName $resourceGroupName `
-TemplateParameterFile .\bicep\params\azuredeploy.parameters.json `
-TemplateFile .\bicep\azuredeploy.bicep `
-environment $env `
-companyName $companyName `
-Location $location `
-projectName $projectName `
-Verbose 


