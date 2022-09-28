
//@metadata({ Description: 'The name of the Virtual Network to Create' })
param virtualNetworkName string

//@metadata({ Description: 'The address range of the new VNET in CIDR format' })
param virtualNetworkAddressRange string

//@metadata({ Description: 'The name of the subnet created in the new VNET' })
param subnetName string

//@metadata({ Description: 'The address range of the subnet created in the new VNET' })
param subnetRange string

//@metadata({Description: 'The subnet ref ID' })
param subnetRef string

//@metadata({ Description: 'The DNS address(es) of the DNS Server(s) used by the VNET' })
param DNSServerAddress array

param env string

@description('Location for all resources.')
param location string

var nsgSecurityRules = json(loadTextContent('../Params/nsg-rules.json')).securityRules


var dhcpOptions = {
  dnsServers: DNSServerAddress
}

resource networkSecurityGroup 'Microsoft.Network/networkSecurityGroups@2022-01-01' = {
  name: 'nsg-${virtualNetworkName}-${subnetName}-${location}-${env}'
  location: location
  properties: {
    securityRules: nsgSecurityRules
  }

}

resource virtualNetworkName_resource 'Microsoft.Network/virtualNetworks@2020-11-01' = {
  name: virtualNetworkName
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        virtualNetworkAddressRange
      ]
    }
    dhcpOptions: (empty(DNSServerAddress) ? json('null') : dhcpOptions)
    subnets: [
      {
        name: subnetName
        properties: {
          addressPrefix: subnetRange
          networkSecurityGroup: {
            id: networkSecurityGroup.id
          }
        }
      }
    ]
  }
}

