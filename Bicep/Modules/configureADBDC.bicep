param extName string
param location string
param adminUsername string
param projectName string
param containerName string
param product string
param environment string
param baseTime string = utcNow('u')

@secure()
param adminPassword string
param domainName string
//param adBDCConfigurationScript string
//param adBDCConfigurationFunction string
//param adBDCConfigurationModulesURL string

//@secure()
//param _artifactsLocationSasToken string

var _artifactsLocationSasToken = saExisting.listServiceSas('2022-05-01', {
  canonicalizedResource: '/blob${saExisting.name}/${containerName}'
  signedResource: 'c'
  signedProtocol: 'https'
  signedPermission: 'r'
  signedServices: 'b'
  signedExpiry: dateTimeAdd(baseTime, 'PT1H')
}).serviceSasToken

resource saExisting 'Microsoft.Storage/storageAccounts@2022-05-01' existing = {
  name: 'stdeployment-${projectName}-${environment}'
}



resource containerExt 'Microsoft.Storage/storageAccounts/blobServices/containers@2022-05-01' existing = {
  name: '${saExisting.name}/${containerName}'
}


resource ext 'Microsoft.Compute/virtualMachines/extensions@2020-12-01' = {
  name: extName
  location: location
  properties: {
    publisher: 'Microsoft.Powershell'
    type: 'DSC'
    typeHandlerVersion: '2.24'
    autoUpgradeMinorVersion: true
    settings: {
      Configuration: {
        url: '${saExisting.properties.primaryEndpoints.blob}-blob${containerName}/ConfigureADBDC.ps1.zip'
      }
      configurationArguments: {
        domainName: domainName
      }
    }
    protectedSettings: {
      configurationUrlSasToken: '?${_artifactsLocationSasToken}'
      configurationArguments: {
        adminCreds: {
          userName: adminUsername
          password: adminPassword
        }
      }
    }
  }
}
