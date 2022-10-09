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


resource resourceGroup 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: 'rg-${projectName}-${product}-${companyName}-${environment}-${location}'
  location: location
}


module CreateVNet 'Modules/vnet.bicep' = [ for (network,i) in vnets: {
  name: 'CreateVNet-${network.name}'
  scope: resourceGroup
  params: {
    virtualNetworkName: network.name
    virtualNetworks: network
    virtualNetworkAddressRange: network.addressPrefix
    subnetName: network.subnets.name
    subnetRange: network.subnets.subnetPrefix
    location: location
    subnets: network.subnets
    companyName: companyName
    environment:environment
    product:product
  }
}]


module vmModule 'Modules/vms.bicep' = [for (machine,i) in vms: {
  name: 'vmCreation-${machine.name}'
  scope: resourceGroup
  dependsOn: CreateVNet
  params: {
    adminPassword:adminPassword
    adminUsername:adminUsername
    companyName:companyName
    dnsPrefix:dnsPrefix
    environment:environment
    ipAddress:ipAddress
    location:location
    product:product
    projectName:projectName
    subnets: CreateVNet[i].outputs.subnetsArray[i]
    vms: machine
    publicIPAddressNameVar: publicIPAddressNameVar
    imageOffer:imageOffer
    imagePublisher:imagePublisher
    imageSKU:imageSKU
    publicIPSKU:publicIPSKU
    domainName:domainName
    publicIPAddressType: publicIPAddressType
  }
}]

module UpdateVNetDNS1 'Modules/vnet.bicep' = [for (dns,i) in vnets: {
  name: 'UpdateVNetDNS1-${dns.name}'
  scope: resourceGroup
  dependsOn: [
    vmModule[i]
  ]
  params: {
    virtualNetworkName: CreateVNet[i].outputs.vnetsArray[i].name
    virtualNetworkAddressRange: CreateVNet[i].outputs.vnetsArray[i].addressSpace.addressPrefix
    subnetName: CreateVNet[i].outputs.subnetsArray[i].name
    subnetRange: CreateVNet[i].outputs.subnetsArray[i].addressPrefix
    DNSServerAddress: [
      ipAddress[0]
    ]
    location: location
    companyName:companyName
    environment:environment
    product:product
    subnets:dns.subnets
    virtualNetworks:dns
  }
}]



module UpdateBDCNIC 'Modules/nic.bicep'  = {
  name: 'UpdateBDCNIC'
  scope: resourceGroup
  params: {
    nicName: vmModule[1].outputs.nicArray[0].name
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          privateIPAllocationMethod: 'Static'
          privateIPAddress: ipAddress[1]
          subnet: {
            id: CreateVNet[0].outputs.subnetsArray[0].id
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
    extName: '${vmModule[1].outputs.vmArray[1].name}/PepareBDC'
    location: location
    adminUsername: adminUsername
    adminPassword: adminPassword
    domainName: domainName
    product: product
    projectName: projectName
    environment: environment
    containerName: vmModule[1].outputs.containerOutput.name
    

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
    subnetName: CreateVNet[0].outputs.subnetsArray[0].subnets.name
    subnetRange: CreateVNet[0].outputs.subnetsArray[0].subnets.addressPrefix
    subnets: CreateVNet[0].outputs.subnetsArray[0].subnets
    virtualNetworkAddressRange: CreateVNet[0].outputs.vnetsArray[0].virtualNetworks.AddressPrefix
    virtualNetworkName: CreateVNet[0].outputs.vnetsArray[0].virtualNetworks.Name
    virtualNetworks: CreateVNet[0].outputs.vnetsArray[0].virtualNetworks
  }
  dependsOn: [
    ConfiguringBackupADDomainController
  ]
}
