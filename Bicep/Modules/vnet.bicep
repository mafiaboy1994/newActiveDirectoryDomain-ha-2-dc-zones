
@metadata({ 
  Description: 'The name of the Virtual Network to Create' 
})
param virtualNetworkName string

@metadata({ 
  Description: 'The address range of the new VNET in CIDR format' 
})
param virtualNetworkAddressRange string

@description('environment for deployed resources, e.g. prod, dev, test etc')
param environment string


@description('Company name that resources are being deployed for')
param companyName string

@description('products being deployed')
param product string

@metadata({ 
  Description: 'The name of the subnet created in the new VNET' 
})
param subnetName string

param subnets array

@metadata({ 
  Description: 'The address range of the subnet created in the new VNET' 
})
param subnetRange string

@metadata({ 
  Description: 'The DNS address(es) of the DNS Server(s) used by the VNET' 
})
param DNSServerAddress array = []

@description('Location for all resources.')
param location string

var dhcpOptions = {
  dnsServers: DNSServerAddress
}

var networkNameVar = 'vnets-${virtualNetworkName}-${environment}-${location}'


var nsgSecurityRules = json(loadTextContent('../params/nsgRules.json')).securityRules


resource virtualNetwork 'Microsoft.Network/virtualNetworks@2020-11-01' = {
  name: networkNameVar
  dependsOn: [
    networkSecurityGroup
  ]
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        virtualNetworkAddressRange
      ]
    }
    dhcpOptions: (empty(DNSServerAddress) ? json('null') : dhcpOptions)
    subnets: [ for (subnet,i) in subnets: {
      name: subnetName
        properties: {
          addressPrefix: subnetRange
          networkSecurityGroup: {
            id: resourceId('Microsoft.Network/networkSecurityGroups', 'nsg-${subnetName}-${i+1}')
          }
      } 
    }]
  }
}

resource networkSecurityGroup 'Microsoft.Network/networkSecurityGroups@2020-11-01' = [for (group,i) in subnets: {
  name: 'nsg-${subnetName}-${i+1}'
  location: location
  properties: {
    securityRules: nsgSecurityRules
  }
}]

output subnets array = [for (name,i) in subnets: {
  subnets: virtualNetwork.properties.subnets[i]
}]

output subnetRef array = [for (name,i) in subnets: {
  subnets: virtualNetwork.properties.subnets[i].id
}]

output subnetsIdArray array = [for (name,i) in subnets: {
  id: virtualNetwork.properties.subnets[i].id
}]

output subnetsNameArray array = [for (name,i) in subnets: {
  name: virtualNetwork.properties.subnets[i].name
}]

output subnetsRangeArray array = [for(name,i) in subnets: {
  subnetRange: virtualNetwork.properties.subnets[0].properties.addressPrefix
}]
 
output nsgArray array = [for(name,i) in subnets: {
  nsg: networkSecurityGroup[i]
}]
