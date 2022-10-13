@description('The DNS prefix for the public IP address used by the Load Balancer')
param dnsPrefix string

@description('Size of the VM for the controller')
param vmSize string = 'Standard_DS2_v2'

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

param subnetsIdArray array

@description('environment for deployed resources, e.g. prod, dev, test etc')
param environment string

@description('Company name that resources are being deployed for')
param companyName string

@description('products being deployed')
param product string

param ipAddress array

param imagePublisher string
param imageOffer string
param imageSKU string
param publicIPSKU string
param publicIPAddressNameVar string
param publicIPAddressType string
param vms array

param containerName string

@description('current date for the deployment records. Do not overwrite')
//param currentDate string = utcNow('yyyy-dd-mm')
param currentDate string = utcNow('u')

@description('The FQDN of the AD Domain created ')
param domainName string


var publicIpAddressId = {
  id: publicIPAddressName.id
}

var _artifactsLocationSasToken = saExisting.listServiceSas('2022-05-01', {
  canonicalizedResource: '/blob/${saExisting.name}/${containerName}'
  signedResource: 'c'
  signedProtocol: 'https'
  signedPermission: 'r'
  signedExpiry: dateTimeAdd(currentDate, 'PT1H')
  signedServices: 'b'
}).serviceSasToken


resource saExisting 'Microsoft.Storage/storageAccounts@2022-05-01' existing = {
  name: 'st${projectName}${environment}'
}


/*
resource containerExt 'Microsoft.Storage/storageAccounts/blobServices/containers@2022-05-01' existing = {
  name: '${saExisting.name}/${containerName}'
}
*/

resource publicIPAddressName 'Microsoft.Network/publicIPAddresses@2020-11-01' = {
  name: publicIPAddressNameVar
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

resource nicNameResource 'Microsoft.Network/networkInterfaces@2020-11-01' = [for (nic,i) in vms:{
  name: 'nic-${nic.name}-${environment}-${location}'
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
            id: subnetsIdArray[0].id
          }
        }
      }
    ]
  }
  dependsOn: [
  ]
}]


resource vmNameResource 'Microsoft.Compute/virtualMachines@2020-12-01' =  [for (vm,i) in vms:{
  name: 'vm-${vm.name}'
  location: location 
  zones: [
    '1'
  ]
  properties: {
    hardwareProfile: {
      vmSize: vmSize
    }
    osProfile: {
      computerName: 'vm-${vm.name}'
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
          id: resourceId('Microsoft.Network/networkInterfaces', 'nic-${vm.name}-${environment}-${location}')
        }
      ]
    }
  }
  dependsOn: [
    nicNameResource
  ]
}]

resource vmName_0_CreateAdForest 'Microsoft.Compute/virtualMachines/extensions@2020-12-01' = {
  name: 'vm-${vms[0].name}/CreateAdForest'
  location: location
  properties: {
    publisher: 'Microsoft.Powershell'
    type: 'DSC'
    typeHandlerVersion: '2.24'
    autoUpgradeMinorVersion: true
    settings: {
      configuration: {
        url: '${saExisting.properties.primaryEndpoints.blob}${containerName}/DSC/CreateADPDC.ps1.zip'
        script: 'CreateADPDC.ps1'
        function: 'CreateADPDC'
      }
      configurationArguments: {
        domainName: domainName
      }
    }
    protectedSettings: {
      configurationSettings: {
        configurationUrlSasToken: '?${_artifactsLocationSasToken}'
      }
      configurationArguments: {
        adminCreds: {
          userName: adminUsername
          password: adminPassword
        }
      }
    } 
  }
  dependsOn: [
    vmNameResource
    vmName_1_PepareBDC
  ]
}

resource vmName_1_PepareBDC 'Microsoft.Compute/virtualMachines/extensions@2020-12-01' = {
  name: 'vm-${vms[1].name}/PepareBDC'
  location: location
  properties: {
    publisher: 'Microsoft.Powershell'
    type: 'DSC'
    typeHandlerVersion: '2.24'
    autoUpgradeMinorVersion: true
    settings: {
      configuration: {
        url: '${saExisting.properties.primaryEndpoints.blob}${containerName}/DSC/PrepareADBDC.ps1.zip'
        script: 'PrepareADBDC.ps1'
        function: 'PrepareADBDC'
      }
      configurationArguments: {
        DNSServer: ipAddress[0]
      }
    }
    protectedSettings: {
      configurationUrlSasToken: '?${_artifactsLocationSasToken}'
    }
  }
  dependsOn: [
    vmNameResource
  ]
}


output nicNameArray array = [for (nic,i) in vms: {
  name: nicNameResource[i].name 
}]


output vmArray array = [for (vm,i) in vms:{
  name: vmNameResource[i]
}]


output vmNameArray array = [for (vm,i) in vms: {
  name: vmNameResource[i].name
}]
//output containerOutput object = containerExt
