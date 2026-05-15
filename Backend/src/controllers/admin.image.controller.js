const axios = require('axios');
const { successResponse, errorResponse } = require('../common/responses/apiResponse');
const { HTTP_STATUS } = require('../common/constants');

const toInteger = (value, fallback) => {
  const parsed = Number.parseInt(value, 10);
  return Number.isFinite(parsed) ? parsed : fallback;
};

const resizeImage = async (req, res) => {
  const apiUrl = process.env.RESIZE_IMAGE_API_URL;
  const apiKey = process.env.RESIZE_IMAGE_API_KEY;

  if (!apiUrl || !apiKey) {
    return errorResponse(
      res,
      'Resize image API Gateway configuration is missing',
      HTTP_STATUS.INTERNAL_SERVER_ERROR
    );
  }

  const bucket = req.body.bucket || process.env.AWS_S3_BUCKET_NAME;
  const key = String(req.body.key || '').replace(/^\/+/, '');
  const width = toInteger(req.body.width, 300);
  const height = toInteger(req.body.height, 300);

  if (!key) {
    return errorResponse(res, 'key is required', HTTP_STATUS.BAD_REQUEST);
  }

  if (bucket !== process.env.AWS_S3_BUCKET_NAME) {
    return errorResponse(res, 'bucket is not allowed', HTTP_STATUS.BAD_REQUEST);
  }

  if (width < 1 || width > 2000 || height < 1 || height > 2000) {
    return errorResponse(
      res,
      'width and height must be between 1 and 2000',
      HTTP_STATUS.BAD_REQUEST
    );
  }

  try {
    const response = await axios.post(
      apiUrl,
      { bucket, key, width, height },
      {
        headers: {
          'x-api-key': apiKey,
          'Content-Type': 'application/json'
        },
        timeout: 30000
      }
    );

    return successResponse(res, 'Image resized through API Gateway', {
      apiGatewayUrl: apiUrl,
      request: { bucket, key, width, height },
      result: response.data
    });
  } catch (error) {
    const statusCode = error.response?.status || HTTP_STATUS.INTERNAL_SERVER_ERROR;
    const message = error.response?.data?.message || error.message || 'Resize image request failed';

    return errorResponse(res, message, statusCode, {
      apiGatewayStatus: error.response?.status,
      apiGatewayData: error.response?.data
    });
  }
};

module.exports = {
  resizeImage
};
