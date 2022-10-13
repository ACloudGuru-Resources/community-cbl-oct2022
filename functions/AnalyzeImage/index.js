const { ComputerVisionClient } = require('@azure/cognitiveservices-computervision');
const { ApiKeyCredentials } = require('@azure/ms-rest-js');
const {
  BlobSASPermissions,
  BlobServiceClient,
  SharedKeyCredential,
  generateBlobSASQueryParameters,
} = require("@azure/storage-blob");

// Authentication and Client for Cognitive Services (Computer Vision)
const key = process.env.AZURE_COMPUTER_VISION_KEY;
const endpoint = process.env.AZURE_COMPUTER_VISION_ENDPOINT;
const credentials = new ApiKeyCredentials({ inHeader: { 'Ocp-Apim-Subscription-Key': key } });
const computerVisionClient = new ComputerVisionClient(credentials, endpoint);

// Authentication and Client for Blob Storage
const blobServiceClient = BlobServiceClient.fromConnectionString(
  process.env.AZURE_STORAGE_CONNECTION_STRING
);
const containerClient = blobServiceClient.getContainerClient('images');

// Computer Vision - Visual Features Config
const visualFeatures = [
  "ImageType",
  "Faces",
  "Categories",
  "Tags",
  "Description",
  "Objects"
];

// This generates a URL that Cognitive Services can use to access the
// image.
const getBlobSasUri = (context) => {
  let blobName = context.bindingData.blobTrigger.slice(7);
  const sasOptions = {
      containerName: containerClient.containerName,
      blobName: blobName,
      startsOn: new Date(),
      expiresOn: new Date(new Date().valueOf() + 3600 * 1000),
      permissions: BlobSASPermissions.parse("r")
  };
  const sasToken = generateBlobSASQueryParameters(sasOptions, blobServiceClient.credential).toString();
  return `${containerClient.getBlockBlobClient(blobName).url}?${sasToken}`;
}

// Handler that runs when the trigger is fired
module.exports = async function (context) {
  const uri = getBlobSasUri(context)
  const analysis = await computerVisionClient.analyzeImage(uri, { visualFeatures });
  context.bindings.outputData = JSON.stringify(analysis);
  return;
};
