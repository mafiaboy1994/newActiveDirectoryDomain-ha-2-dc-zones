targetScope = 'subscription'

@description('The name of the Administrator of the new VM and Domain')
param adminUsername string

@description('name of project')
param projectName string

@description('Location for the VM, only certain regions support zones during preview.')
@allowed([
  'centralus'
  'eastus'
  'eastus2'
  'francecentral'
  'northeurope'
  'southeastasia'
  'ukwest'
  'uksouth'
  'westus2'
  'westeurope'
])
param location string

@description('The password for the Administrator account of the new VM and Domain')
@secure()
param adminPassword string

@description('environment for deployed resources, e.g. prod, dev, test etc')
param environment string

@description('Company name that resources are being deployed for')
param companyName string

@description('products being deployed')
param product string

@description('The FQDN of the AD Domain created ')
param domainName string

param vnets array

@description('The DNS prefix for the public IP address used by the Load Balancer')
param dnsPrefix string

@description('vm array')
param vms array

param containerName string = 'templates'

var imagePublisher = 'MicrosoftWindowsServer'
var imageOffer = 'WindowsServer'
var imageSKU = '2022-Datacenter'
var publicIPSKU = 'Standard'
//var publicIPAddressName_var = 'pip-${product}-${location}'

var publicIPAddressNameVar = 'pip-AAD-01-${environment}${location}'

var publicIPAddressType = 'Static'



//var vnetTemplateUri = uri(_artifactsLocation, 'nestedtemplates/vnet.json${_artifactsLocationSasToken}')
//var nicTemplateUri = uri(_artifactsLocation, 'nestedtemplates/nic.json${_artifactsLocationSasToken}')

var ipAddress = [
  '10.0.0.10'
  '10.0.0.11'
]


resource resourceGroup 'Microsoft.Resources/resourceGroups@2021-04-01' existing = {
  name: 'rg-${projectName}-${companyName}-${product}-${environment}-${location}'
}


module CreateVNet 'Modules/vnet.bicep' = [ for (network,i) in vnets: {
  name: 'CreateVNet-${network.name}'
  scope: resourceGroup
  params: {
    virtualNetworkName: network.name
    subnets: network.subnets
    virtualNetworkAddressRange: network.addressPrefix
    subnetName: network.subnets[i].name
    subnetRange: network.subnets[i].subnetPrefix
    location: location
    companyName: companyName
    environment:environment
    product:product
  }
}]


module vmModule 'Modules/vms.bicep' =  {
  name: 'vmCreation'
  scope: resourceGroup
  dependsOn: CreateVNet
  params: {
    adminPassword:adminPassword
    adminUsername:adminUsername
    containerName: containerName
    companyName:companyName
    dnsPrefix:dnsPrefix
    environment:environment
    ipAddress:ipAddress
    location:location
    product:product
    projectName:projectName
    subnetsIdArray: CreateVNet[0].outputs.subnetsIdArray
    publicIPAddressNameVar: publicIPAddressNameVar
    imageOffer:imageOffer
    imagePublisher:imagePublisher
    imageSKU:imageSKU
    publicIPSKU:publicIPSKU
    domainName:domainName
    publicIPAddressType: publicIPAddressType
    vms: vms
  }
}

module UpdateVNetDNS1 'Modules/vnet.bicep' =  {
  name: 'UpdateVNetDNS1'
  scope: resourceGroup
  dependsOn: [
    vmModule
  ]
  params: {
    virtualNetworkName: 'vnets-${vnets[0].name}-${environment}-${location}'
    virtualNetworkAddressRange: vnets[0].addressPrefix
    subnetName: CreateVNet[0].outputs.subnetsNameArray[0].name
    subnets: CreateVNet[0].outputs.subnets
    subnetRange: CreateVNet[0].outputs.subnetsRangeArray[0].subnetRange
    DNSServerAddress: [
      ipAddress[0]
    ]
    location: location
    companyName:companyName
    environment:environment
    product:product
  }
}



module UpdateBDCNIC 'Modules/nic.bicep'  = {
  name: 'UpdateBDCNIC'
  scope: resourceGroup
  params: {
    nicName: vmModule.outputs.nicNameArray[1].name
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          privateIPAllocationMethod: 'Static'
          privateIPAddress: ipAddress[1]
          subnet: {
            id: CreateVNet[0].outputs.subnetsIdArray[0].id
          }
        }
      }
    ]
    dnsServers: [
      ipAddress[0]
    ]
    location: location
  }
  dependsOn: [
    UpdateVNetDNS1
  ]
}

module ConfiguringBackupADDomainController 'Modules/configureADBDC.bicep' /*TODO: replace with correct path to [variables('configureADBDCTemplateUri')]*/ = {
  name: 'ConfiguringBackupADDomainController'
  scope: resourceGroup
  params: {
    extName: '${vmModule.outputs.vmNameArray[1].name}/PepareBDC'
    location: location
    adminUsername: adminUsername
    adminPassword: adminPassword
    domainName: domainName
    product: product
    projectName: projectName
    environment: environment
    containerName: containerName

  }
  dependsOn: [
    UpdateBDCNIC
  ]
}

module UpdateVNetDNS2  'Modules/vnet.bicep' = {
  name: 'UpdateVNetDNS2'
  scope: resourceGroup
  params: {
    DNSServerAddress: ipAddress
    location: location
    companyName:companyName
    environment:environment
    product:product
    subnetName: CreateVNet[0].outputs.subnetsNameArray[0].name
    subnetRange: CreateVNet[0].outputs.subnetsRangeArray[0].subnetRange
    subnets: CreateVNet[0].outputs.subnets
    virtualNetworkAddressRange: vnets[0].addressPrefix
    virtualNetworkName: 'vnets-${vnets[0].name}-${environment}-${location}'
  }
  dependsOn: [
    ConfiguringBackupADDomainController
  ]
}
