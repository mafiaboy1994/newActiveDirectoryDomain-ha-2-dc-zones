@description('The name of the Administrator of the new VM and Domain')
param adminUsername string

@description('Location for the VM, only certain regions support zones during preview.')
param location string

@description('The password for the Administrator account of the new VM and Domain')
@secure()
param adminPassword string

@description('The FQDN of the AD Domain created ')
param domainName string = 'contoso.local'

@description('The DNS prefix for the public IP address used by the Load Balancer')
param dnsPrefix string

@description('Size of the VM for the controller')
param vmSize string = 'Standard_D1s_v2'

@description('The location of resources such as templates and DSC modules that the script is dependent')
param _artifactsLocation string

@description('Auto-generated token to access _artifactsLocation')
@secure()
param _artifactsLocationSasToken string

param env string


param imagePublisher string
param imageOffer string
param imageSKU string
param virtualNetworkName string
param virtualNetworkAddressRange string
param adSubnetName string
param adSubnet string
param adSubnetRef string
param publicIPSKU string
param publicIPAddressType string

param vnetTemplateUri string
param nicTemplateUri string
param vmName_var array
param nicName_var array
param ipAddress array

param configureADBDCTemplateUri string
param adBDCConfigurationModulesURL string
param adBDCConfigurationScript string
param adBDCConfigurationFunction string


var publicIpAddressId  = {
  id: publicIPAddressName.id
}

var publicIPAddressName_var = 'adPublicIp'



resource nicName 'Microsoft.Network/networkInterfaces@2020-11-01' = [for i in range(0, 2): {
  name: nicName_var[i]
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          privateIPAllocationMethod: 'Static'
          privateIPAddress: ipAddress[i]
          publicIPAddress: ((i == 0) ? publicIpAddressId : json('null'))
          subnet: {
            id: adSubnetRef
          }
        }
      }
    ]
  }
  dependsOn: [
    CreateVNet
  ]
}]

resource vmName 'Microsoft.Compute/virtualMachines@2020-12-01' = [for i in range(0, 2): {
  name: vmName_var[i]
  location: location
  zones: [
    ('${i + 1}')
  ]
  properties: {
    hardwareProfile: {
      vmSize: vmSize
    }
    osProfile: {
      computerName: vmName_var[i]
      adminUsername: adminUsername
      adminPassword: adminPassword
    }
    storageProfile: {
      imageReference: {
        publisher: imagePublisher
        offer: imageOffer
        sku: imageSKU
        version: 'latest'
      }
      osDisk: {
        caching: 'ReadOnly'
        createOption: 'FromImage'
        managedDisk: {
          storageAccountType: 'StandardSSD_LRS'
        }
      }
      dataDisks: [
        {
          diskSizeGB: 64
          lun: 0
          createOption: 'Empty'
        }
      ]
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: resourceId('Microsoft.Network/networkInterfaces', nicName_var[i])
        }
      ]
    }
  }
  dependsOn: [
    nicName
  ]
}]

resource vmName_0_CreateAdForest 'Microsoft.Compute/virtualMachines/extensions@2020-12-01' = {
  name: '${vmName_var[0]}/CreateAdForest'
  location: location
  properties: {
    publisher: 'Microsoft.Powershell'
    type: 'DSC'
    typeHandlerVersion: '2.24'
    autoUpgradeMinorVersion: true
    settings: {
      configuration: {
        url: uri(_artifactsLocation, 'DSC/CreateADPDC.ps1.zip')
        script: 'CreateADPDC.ps1'
        function: 'CreateADPDC'
      }
      configurationArguments: {
        domainName: domainName
      }
    }
    protectedSettings: {
      configurationUrlSasToken: _artifactsLocationSasToken
      configurationArguments: {
        adminCreds: {
          userName: adminUsername
          password: adminPassword
        }
      }
    }
  }
  dependsOn: [
    vmName
  ]
}

resource vmName_1_PepareBDC 'Microsoft.Compute/virtualMachines/extensions@2020-12-01' = {
  name: '${vmName_var[1]}/PepareBDC'
  location: location
  properties: {
    publisher: 'Microsoft.Powershell'
    type: 'DSC'
    typeHandlerVersion: '2.24'
    autoUpgradeMinorVersion: true
    settings: {
      configuration: {
        url: uri(_artifactsLocation, 'DSC/PrepareADBDC.ps1.zip')
        script: 'PrepareADBDC.ps1'
        function: 'PrepareADBDC'
      }
      configurationArguments: {
        DNSServer: ipAddress[0]
      }
    }
    protectedSettings: {
      configurationUrlSasToken: _artifactsLocationSasToken
    }
  }
  dependsOn: [
    vmName
  ]
}



module CreateVNet 'vnet.bicep' = {
  name: 'CreateVNet'
  params: {
    virtualNetworkName: virtualNetworkName
    virtualNetworkAddressRange: virtualNetworkAddressRange
    subnetName: adSubnetName
    subnetRange: adSubnet
    subnetRef: adSubnetRef
    location: location
    DNSServerAddress: ipAddress
    env: env
  }
}


module UpdateVNetDNS1 '../nestedtemplates/vnet.json' = {
  name: 'UpdateVNetDNS1'
  params: {
    virtualNetworkName: virtualNetworkName
    virtualNetworkAddressRange: virtualNetworkAddressRange
    subnetName: adSubnetName
    subnetRange: adSubnet
    DNSServerAddress: [
      ipAddress[0]
    ]
    location: location
  }
  dependsOn: [
    vmName_0_CreateAdForest
    vmName_1_PepareBDC
  ]
}

module UpdateBDCNIC '../nestedtemplates/nic.json'  = {
  name: 'UpdateBDCNIC'
  params: {
    nicName: nicName_var[1]
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          privateIPAllocationMethod: 'Static'
          privateIPAddress: ipAddress[1]
          subnet: {
            id: adSubnetRef
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

module ConfiguringBackupADDomainController '../nestedtemplates/configureADBDC.json' = {
  name: 'ConfiguringBackupADDomainController'
  params: {
    extName: '${vmName_var[1]}/PepareBDC'
    location: location
    adminUsername: adminUsername
    adminPassword: adminPassword
    domainName: domainName
    adBDCConfigurationScript: adBDCConfigurationScript
    adBDCConfigurationFunction: adBDCConfigurationFunction
    adBDCConfigurationModulesURL: adBDCConfigurationModulesURL
    //'_artifactsLocationSasToken': _artifactsLocationSasToken
    _artifactsLocationSasToken: _artifactsLocationSasToken
  }
  dependsOn: [
    UpdateBDCNIC
  ]
}

module UpdateVNetDNS2 '../nestedtemplates/vnet.json' = {
  name: 'UpdateVNetDNS2'
  params: {
    virtualNetworkName: virtualNetworkName
    virtualNetworkAddressRange: virtualNetworkAddressRange
    subnetName: adSubnetName
    subnetRange: adSubnet
    DNSServerAddress: ipAddress
    location: location
  }
  dependsOn: [
    ConfiguringBackupADDomainController
  ]
}


resource publicIPAddressName 'Microsoft.Network/publicIPAddresses@2020-11-01' = {
  name: publicIPAddressName_var
  location: location
  sku: {
    name: publicIPSKU
  }
  zones: [
    '1'
  ]
  properties: {
    publicIPAllocationMethod: publicIPAddressType
    dnsSettings: {
      domainNameLabel: dnsPrefix
    }
  }
}
