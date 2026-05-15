const path = require('node:path');
const sharp = require('sharp');
const {
  S3Client,
  GetObjectCommand,
  PutObjectCommand
} = require('@aws-sdk/client-s3');

const s3 = new S3Client({});
const allowedBucket = process.env.USER_ASSET_BUCKET;
const outputPrefix = process.env.OUTPUT_PREFIX || 'resized';

const jsonResponse = (statusCode, payload) => ({
  statusCode,
  headers: {
    'Content-Type': 'application/json',
    'Access-Control-Allow-Origin': '*'
  },
  body: JSON.stringify(payload)
});

const streamToBuffer = async (stream) => {
  const chunks = [];
  for await (const chunk of stream) {
    chunks.push(Buffer.isBuffer(chunk) ? chunk : Buffer.from(chunk));
  }
  return Buffer.concat(chunks);
};

const parseBody = (event) => {
  if (!event.body) return {};
  const rawBody = event.isBase64Encoded
    ? Buffer.from(event.body, 'base64').toString('utf8')
    : event.body;
  return JSON.parse(rawBody);
};

const toInteger = (value, fallback) => {
  const parsed = Number.parseInt(value, 10);
  return Number.isFinite(parsed) ? parsed : fallback;
};

const buildOutputKey = (key, width, height) => {
  const parsed = path.posix.parse(key);
  const safeDir = parsed.dir ? `${parsed.dir}/` : '';
  const safeName = parsed.name || 'image';
  return `${outputPrefix}/${safeDir}${safeName}-${width}x${height}.jpg`;
};

exports.handler = async (event) => {
  try {
    const body = parseBody(event);
    const bucket = body.bucket || allowedBucket;
    const key = String(body.key || '').replace(/^\/+/, '');
    const width = toInteger(body.width, 300);
    const height = toInteger(body.height, 300);

    if (!allowedBucket || bucket !== allowedBucket) {
      return jsonResponse(400, {
        message: 'Bucket is not allowed for image resize'
      });
    }

    if (!key) {
      return jsonResponse(400, { message: 'key is required' });
    }

    if (width < 1 || width > 2000 || height < 1 || height > 2000) {
      return jsonResponse(400, {
        message: 'width and height must be between 1 and 2000'
      });
    }

    const source = await s3.send(new GetObjectCommand({
      Bucket: bucket,
      Key: key
    }));
    const sourceBuffer = await streamToBuffer(source.Body);
    const outputBuffer = await sharp(sourceBuffer)
      .rotate()
      .resize(width, height, {
        fit: 'inside',
        withoutEnlargement: true
      })
      .jpeg({ quality: 85 })
      .toBuffer();

    const outputKey = buildOutputKey(key, width, height);

    await s3.send(new PutObjectCommand({
      Bucket: bucket,
      Key: outputKey,
      Body: outputBuffer,
      ContentType: 'image/jpeg'
    }));

    console.log(JSON.stringify({
      event: 'resize-image-completed',
      bucket,
      key,
      outputKey,
      width,
      height
    }));

    return jsonResponse(200, {
      outputBucket: bucket,
      outputKey,
      width,
      height
    });
  } catch (error) {
    console.error('Resize image failed', error);
    return jsonResponse(500, {
      message: 'Resize image failed',
      error: error.message
    });
  }
};
