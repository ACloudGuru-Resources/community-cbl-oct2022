/* 
  CLOUD BUILDER LIVE

  This creates a function app, storage account, and Computer Vision service
  account along with all necessary items to make this serverless image
  analyzer work.
  
  This file was adapted from the Azure Quickstarts from Microsoft:
  https://github.com/Azure/azure-quickstart-templates
*/

@description('Specifies region of all resources.')
param location string = resourceGroup().location

@description('Suffix for function app, storage account, and key vault names.')
param appNameSuffix string = uniqueString(resourceGroup().id)

@description('Storage account SKU name.')
param storageSku string = 'Standard_LRS'

@description('SKU for Computer Vision Cognitive Services Account')
param sku string = 'F0'

var functionAppName = 'ImageAnalyzer-${appNameSuffix}'
var appServicePlanName = 'IAFunctionPlan'
var storageAccountName = 'cbl${replace(appNameSuffix, '-', '')}'
var applicationInsightsName = 'FnAppInsights'
var cognitiveServiceName = 'CognitiveService-${appNameSuffix}'

// This resource will enable use to submit an image and get back details and tags
resource cognitiveService 'Microsoft.CognitiveServices/accounts@2021-10-01' = {
  name: cognitiveServiceName
  location: location
  sku: {
    name: sku
  }
  kind: 'ComputerVision'
  properties: {
    apiProperties: {
      statisticsEnabled: false
    }
  }
}

// This is the storage account where we will upload our images and also store
// the thumnails and JSON data. It also will be our storage account for our
// function app.
resource storageAccount 'Microsoft.Storage/storageAccounts@2021-04-01' = {
  name: storageAccountName
  location: location
  sku: {
    name: storageSku
  }
  kind: 'StorageV2'
  properties: {
    supportsHttpsTrafficOnly: true
    encryption: {
      services: {
        file: {
          keyType: 'Account'
          enabled: true
        }
        blob: {
          keyType: 'Account'
          enabled: true
        }
      }
      keySource: 'Microsoft.Storage'
    }
    accessTier: 'Hot'
  }
}

// This is for a container within our storage account.  Note that we are
// making the images publicly accessible.
resource container 'Microsoft.Storage/storageAccounts/blobServices/containers@2021-06-01' = {
  name: '${storageAccountName}/default/images'
  properties: {
    publicAccess: 'Blob'
  }
  dependsOn: [
    storageAccount
  ]
}

// This is the application insights component that will be used by the
// function app.
resource applicationInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: applicationInsightsName
  location: location
  kind: 'web'
  properties: {
    Application_Type: 'web'
    Request_Source: 'rest'
  }
}

// This is our app service plan name for the function app
resource plan 'Microsoft.Web/serverfarms@2020-12-01' = {
  name: appServicePlanName
  location: location
  kind: 'functionapp'
  sku: {
    name: 'Y1'
    tier: 'Dynamic'
  }
  properties: {}
}

// This is the function app itself
resource functionApp 'Microsoft.Web/sites@2020-12-01' = {
  name: functionAppName
  location: location
  kind: 'functionapp'
  properties: {
    serverFarmId: plan.id
    siteConfig: {
      appSettings: [
        {
          name: 'AzureWebJobsStorage'
          value: 'DefaultEndpointsProtocol=https;AccountName=${storageAccountName};EndpointSuffix=${environment().suffixes.storage};AccountKey=${storageAccount.listKeys().keys[0].value}'
        }
        {
          name: 'WEBSITE_CONTENTAZUREFILECONNECTIONSTRING'
          value: 'DefaultEndpointsProtocol=https;AccountName=${storageAccountName};EndpointSuffix=${environment().suffixes.storage};AccountKey=${storageAccount.listKeys().keys[0].value}'
        }
        {
          name: 'WEBSITE_CONTENTSHARE'
          value: toLower(functionAppName)
        }
        {
          name: 'APPINSIGHTS_INSTRUMENTATIONKEY'
          value: applicationInsights.properties.InstrumentationKey
        }
        {
          name: 'FUNCTIONS_WORKER_RUNTIME'
          value: 'node'
        }
        {
          name: 'FUNCTIONS_EXTENSION_VERSION'
          value: '~4'
        }
        {
          name: 'WEBSITE_NODE_DEFAULT_VERSION'
          value: '~16'
        }
        {
          name: 'AZURE_STORAGE_CONNECTION_STRING'
          value: 'DefaultEndpointsProtocol=https;AccountName=${storageAccount.name};EndpointSuffix=${environment().suffixes.storage};AccountKey=${listKeys(storageAccount.id, storageAccount.apiVersion).keys[0].value}'
        }
        {
          name: 'AZURE_COMPUTER_VISION_KEY'
          value: listKeys(cognitiveService.id, cognitiveService.apiVersion).key1
        }
        {
          name: 'AZURE_COMPUTER_VISION_ENDPOINT'
          value: cognitiveService.properties.endpoint
        }
      ]
    }
    httpsOnly: true
  }
}
