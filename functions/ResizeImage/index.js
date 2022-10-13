const Jimp = require('jimp');

// Resizes an image to 800px width
module.exports = async function (context, originalImage) {
  const image = await Jimp.read(originalImage);
  image.resize(800, Jimp.AUTO);
  const buffer = await image.getBufferAsync(Jimp.MIME_JPEG)
  context.bindings.outputThumbnail = buffer;
  return;
};
