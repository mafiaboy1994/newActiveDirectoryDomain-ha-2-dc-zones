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

@description('The DNS prefix for the public IP address used by the Load Balancer')
param dnsPrefix string

@description('Size of the VM for the controller')
param vmSize string = 'Standard_DS2_v2'

@description('The location of resources such as templates and DSC modules that the script is dependent')
param _artifactsLocation string = deployment().properties.templateLink.uri

@description('Auto-generated token to access _artifactsLocation')
@secure()
param _artifactsLocationSasToken string = ''

var imagePublisher = 'MicrosoftWindowsServer'
var imageOffer = 'WindowsServer'
var imageSKU = '2022-Datacenter'
var virtualNetworkName = 'vnet-${product}-${companyName}-${environment}-uks'
var virtualNetworkAddressRange = '10.0.0.0/24'
var adSubnetName = 'snet-${product}-${environment}'
var adSubnet = '10.0.0.0/24'
var adSubnetRef = resourceId('Microsoft.Network/virtualNetworks/subnets', virtualNetworkName, adSubnetName)
var publicIPSKU = 'Standard'
var publicIPAddressName_var = 'pip-${product}-${location}'
var publicIPAddressType = 'Static'
var publicIpAddressId = {
  id: publicIPAddressName.id
}
var networkSecurityGroupName_var = 'nsg-${adSubnetName}'
var vnetTemplateUri = uri(_artifactsLocation, 'nestedtemplates/vnet.json${_artifactsLocationSasToken}')
var nicTemplateUri = uri(_artifactsLocation, 'nestedtemplates/nic.json${_artifactsLocationSasToken}')
var vmName_var = [
  'vm-DC1-${environment}-uks'
  'vm-DC2-${environment}-uks'
]
var nicName_var = [
  'nic-DC1-${environment}-${product}-uks'
  'nic-DC2-${environment}-${product}-uks'
]
var ipAddress = [
  '10.0.0.10'
  '10.0.0.11'
]
var configureADBDCTemplateUri = uri(_artifactsLocation, 'nestedtemplates/configureADBDC.json${_artifactsLocationSasToken}')
var adBDCConfigurationModulesURL = uri(_artifactsLocation, 'DSC/ConfigureADBDC.ps1.zip')
var adBDCConfigurationScript = 'ConfigureADBDC.ps1'
var adBDCConfigurationFunction = 'ConfigureADBDC'

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

resource networkSecurityGroupName 'Microsoft.Network/networkSecurityGroups@2020-11-01' = {
  name: concat(networkSecurityGroupName_var)
  location: location
  properties: {
    securityRules: [
      {
        name: 'allow-RDP-inbound'
        properties: {
          description: 'Allow inbound RDP traffic'
          protocol: 'Tcp'
          sourcePortRange: '*'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: 'VirtualNetwork'
          access: 'Allow'
          priority: 110
          direction: 'inbound'
          destinationPortRanges: [
            '3389'
          ]
        }
      }
    ]
  }
}

module CreateVNet '?' /*TODO: replace with correct path to [variables('vnetTemplateUri')]*/ = {
  name: 'CreateVNet'
  params: {
    virtualNetworkName: virtualNetworkName
    virtualNetworkAddressRange: virtualNetworkAddressRange
    subnetName: adSubnetName
    subnetRange: adSubnet
    location: location
    networkSecurityGroupName: concat(networkSecurityGroupName_var)
  }
  dependsOn: [
    networkSecurityGroupName
  ]
}

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
    publicIPAddressName
  ]
}]

resource vmName 'Microsoft.Compute/virtualMachines@2020-12-01' = [for i in range(0, 2): {
  name: vmName_var[i]
  location: location
  zones: [
    (i + 1)
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

module UpdateVNetDNS1 '?' /*TODO: replace with correct path to [variables('vnetTemplateUri')]*/ = {
  name: 'UpdateVNetDNS1'
  params: {
    virtualNetworkName: virtualNetworkName
    virtualNetworkAddressRange: virtualNetworkAddressRange
    subnetName: adSubnetName
    subnetRange: adSubnet
    DNSServerAddress: [
      ipAddress[0]
    ]
    networkSecurityGroupName: concat(networkSecurityGroupName_var)
    location: location
  }
  dependsOn: [
    vmName_0_CreateAdForest
    vmName_1_PepareBDC
  ]
}

module UpdateBDCNIC '?' /*TODO: replace with correct path to [variables('nicTemplateUri')]*/ = {
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

module ConfiguringBackupADDomainController '?' /*TODO: replace with correct path to [variables('configureADBDCTemplateUri')]*/ = {
  name: 'ConfiguringBackupADDomainController'
  params: {
    extName: '${vmName_var[1]}/PepareBDC'
    location: location
    adminUsername: adminUsername
    adminPassword: adminPassword
    DomainName: domainName
    adBDCConfigurationScript: adBDCConfigurationScript
    adBDCConfigurationFunction: adBDCConfigurationFunction
    adBDCConfigurationModulesURL: adBDCConfigurationModulesURL
    '_artifactsLocationSasToken': _artifactsLocationSasToken
  }
  dependsOn: [
    UpdateBDCNIC
  ]
}

module UpdateVNetDNS2 '?' /*TODO: replace with correct path to [variables('vnetTemplateUri')]*/ = {
  name: 'UpdateVNetDNS2'
  params: {
    virtualNetworkName: virtualNetworkName
    virtualNetworkAddressRange: virtualNetworkAddressRange
    subnetName: adSubnetName
    subnetRange: adSubnet
    DNSServerAddress: ipAddress
    location: location
    networkSecurityGroupName: concat(networkSecurityGroupName_var)
  }
  dependsOn: [
    ConfiguringBackupADDomainController
  ]
}