
param nicName string

param ipConfigurations array

param dnsServers array

param location string

resource nic 'Microsoft.Network/networkInterfaces@2020-11-01' = {
  name: nicName
  location: location
  properties: {
    ipConfigurations: ipConfigurations
    dnsSettings: {
      dnsServers: dnsServers
    }
  }
}
