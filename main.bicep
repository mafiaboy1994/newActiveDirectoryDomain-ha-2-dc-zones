targetScope = 'subscription'

@description('The name of the Administrator of the new VM and Domain')
param adminUsername string

@description('Location for the VM, only certain regions support zones during preview.')
param location string

@description('The password for the Administrator account of the new VM and Domain')
@secure()
param adminPassword string

param companyName string 
param env string
param product string

@description('The FQDN of the AD Domain created ')
param domainName string = 'contoso.local'

@description('The DNS prefix for the public IP address used by the Load Balancer')
param dnsPrefix string

@description('Size of the VM for the controller')
param vmSize string = 'Standard_D1s_v2'

@description('The location of resources such as templates and DSC modules that the script is dependent')
param _artifactsLocation string = deployment().properties.templateLink.uri

@description('Auto-generated token to access _artifactsLocation')
@secure()
param _artifactsLocationSasToken string = ''

var imagePublisher = 'MicrosoftWindowsServer'
var imageOffer = 'WindowsServer'
var imageSKU = '2019-Datacenter'
var virtualNetworkName = 'adVNET'
var virtualNetworkAddressRange = '10.0.0.0/16'
var adSubnetName = 'adSubnet'
var adSubnet = '10.0.0.0/24'
var adSubnetRef = resourceId('Microsoft.Network/virtualNetworks/subnets', virtualNetworkName, adSubnetName)
var publicIPSKU = 'Standard'

var publicIPAddressType = 'Static'

var vnetTemplateUri = uri(_artifactsLocation, 'nestedtemplates/vnet.json${_artifactsLocationSasToken}')
var nicTemplateUri = uri(_artifactsLocation, 'nestedtemplates/nic.json${_artifactsLocationSasToken}')
var vmName_var = [
  'adPDC'
  'adBDC'
]
var nicName_var = [
  'adPDCNic'
  'adBDCNic'
]
var ipAddress = [
  '10.0.0.4'
  '10.0.0.5'
]
var configureADBDCTemplateUri = uri(_artifactsLocation, 'nestedtemplates/configureADBDC.json${_artifactsLocationSasToken}')
var adBDCConfigurationModulesURL = uri(_artifactsLocation, 'DSC/ConfigureADBDC.ps1.zip')
var adBDCConfigurationScript = 'ConfigureADBDC.ps1'
var adBDCConfigurationFunction = 'ConfigureADBDC'

resource vmArchResourceGroup 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: 'rg-${product}-${companyName}-${env}-${location}'
  location: location
}

module vmModule 'Modules/vm.bicep' = {
  name: 'vmModuleDeployment'
  scope: vmArchResourceGroup
  params: {
    location: location
    _artifactsLocation: _artifactsLocation
    _artifactsLocationSasToken: _artifactsLocationSasToken
    adBDCConfigurationFunction: adBDCConfigurationFunction
    adBDCConfigurationModulesURL: adBDCConfigurationModulesURL
    adBDCConfigurationScript: adBDCConfigurationScript
    adSubnet: adSubnet
    adSubnetName: adSubnetName
    adSubnetRef: adSubnetRef
    adminPassword: adminPassword
    adminUsername: adminUsername
    configureADBDCTemplateUri: configureADBDCTemplateUri
    dnsPrefix: dnsPrefix
    imageOffer: imageOffer
    imagePublisher: imagePublisher
    imageSKU: imageSKU
    ipAddress: ipAddress
    nicName_var: nicName_var
    nicTemplateUri: nicTemplateUri
    publicIPAddressType: publicIPAddressType
    publicIPSKU: publicIPSKU
    virtualNetworkAddressRange: virtualNetworkAddressRange
    virtualNetworkName: virtualNetworkName
    vmName_var: vmName_var
    vnetTemplateUri: vnetTemplateUri
    env: env
    domainName: domainName
    vmSize: vmSize
  }
}
