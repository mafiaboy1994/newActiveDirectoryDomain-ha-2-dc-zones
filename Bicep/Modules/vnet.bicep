
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

param virtualNetworks array

@metadata({ 
  Description: 'The name of the subnet created in the new VNET' 
})
param subnetName string

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

param subnets array


var networkNameVar = 'vnets-${virtualNetworkName}-${environment}-${location}'

var networkSecurityGroupNameNew_var = [for each in subnets: {
  name: 'nsg-${each.name}'
}]

var nsgSecurityRules = json(loadTextContent('../params/nsgRules.json')).securityRules


resource virtualNetwork 'Microsoft.Network/virtualNetworks@2020-11-01' = {
  name: networkNameVar
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: virtualNetworks[0].addressPrefix
    }
    dhcpOptions: (empty(DNSServerAddress) ? json('null') : dhcpOptions)
    subnets: [ for (subnet,i) in subnets: {
      name: subnetName
        properties: {
          addressPrefix: subnetRange
          networkSecurityGroup: {
            id: resourceId('Microsoft.Network/networkSecurityGroups', networkSecurityGroupNameNew_var[i].name)
          }
      } 
    }]
  }
}

resource networkSecurityGroup 'Microsoft.Network/networkSecurityGroups@2020-11-01' = [for (group,i) in subnets: {
  name: networkSecurityGroupNameNew_var[i].name
  location: location
  properties: {
    securityRules: nsgSecurityRules
  }
}]

output subnetRef array = [for (name,i) in subnets: {
  subnets: virtualNetwork.properties.subnets[i].id
}]

output subnetsArray array = [for (name,i) in subnets: {
  subnets: virtualNetwork.properties.subnets[i]
}]

output vnetsArray array = [for (name,i) in virtualNetworks: {
  virtualNetworks: virtualNetwork
}]

output nsgArray array = [for(name,i) in subnets: {
  nsg: networkSecurityGroup[i]
}]
